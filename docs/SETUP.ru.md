# С нуля: Mac, свой VPS и три способа пользоваться Claude

Это руководство для **одного пользователя Mac и его собственного VPS**. Немецкий сервер не обязателен: выходной адрес будет адресом выбранного вами сервера. Примеры серверных команд рассчитаны на **Ubuntu 24.04, amd64, systemd**. На ARM-сервере не устанавливайте указанный ниже пакет Chrome для amd64. Перед началом убедитесь, что у вас есть доступ к Claude и что использование сервиса разрешено в вашем регионе. Прокси не предоставляет подписку и не меняет права аккаунта.

## Что именно вы хотите получить?

| Цель | Пройдите разделы | Как запускать каждый день |
|---|---|---|
| Работать с кодом на Mac через терминал | 1–5 | В папке проекта: `claude` |
| Открывать веб-чат на Mac, не меняя сеть обычного Chrome | 1–4 и 6 | `claude-web` |
| Открывать веб-чат в браузере на Linux и смотреть на него с Mac | 1, 2 и 7 | `claude-web-vps` |

Режимы независимы. Для последнего **не нужны** Tinyproxy, Claude Code и Google Chrome на Mac. Он использует встроенное в macOS приложение «Общий экран» (Screen Sharing). В обратную сторону тоже: для CLI не нужен VNC. Если хотите все три варианта, читайте по порядку.

**Как читать команды.** «На Mac» означает приложение **Терминал** на вашем компьютере. «На VPS» означает терминал после `ssh my-germany-server`. Команда `exit` возвращает с сервера на Mac. В командах для Mac `~` — ваша домашняя папка. После SSH это уже домашняя папка пользователя **сервера**. Не копируйте символы приглашения терминала. Не присылайте никому приватные ключи, ссылки OAuth, пароли VNC или содержимое `~/.claude.json`.

## 1. Подготовьте Mac и доступ к своему серверу

1. В панели VPS найдите **публичный IP**, имя пользователя SSH и порт (обычно `22`). Включите сетевой экран у провайдера: разрешите входящий SSH с вашей административной сети, не открывайте `8888`, `5900–5999`, `15947` или `18787` в интернет. Сохраните доступ к веб-консоли провайдера на случай ошибки с SSH.
2. На Mac откройте Терминал. Если ключа для этого VPS ещё нет, создайте отдельный. При совпадении имени **не перезаписывайте** существующий ключ. Задайте парольную фразу. На сервер в панели провайдера добавляют **только содержимое файла `.pub`** в SSH-ключи нужного пользователя; на уже созданном сервере это может потребовать добавления через консоль провайдера в `~/.ssh/authorized_keys` этого пользователя.

   ```sh
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   ssh-keygen -t ed25519 -f ~/.ssh/claude_vps -C claude-vps
   pbcopy < ~/.ssh/claude_vps.pub
   ssh-add --apple-use-keychain ~/.ssh/claude_vps
   ```

3. На Mac откройте `nano ~/.ssh/config`. В начало файла добавьте блок ниже (если такой `Host` уже есть, редактируйте его, не дублируйте). Замените `203.0.113.10` на IP сервера, `ubuntu` — на свой логин. Имя `my-germany-server` оставьте: это **локальная закладка**, используемая обоими скриптами. Сохранение в nano: `Ctrl+O`, Enter, `Ctrl+X`.

   ```sshconfig
   Host my-germany-server
       HostName 203.0.113.10
       User ubuntu
       Port 22
       IdentityFile ~/.ssh/claude_vps
       IdentitiesOnly yes
       AddKeysToAgent yes
       UseKeychain yes
   ```

4. На Mac: `chmod 600 ~/.ssh/config`, затем `ssh my-germany-server`. При первом входе сравните отпечаток ключа сервера с отпечатком из доверенной консоли VPS и только после совпадения подтвердите. Введите `exit`. Проверка автоматического входа без пароля:

   ```sh
   ssh -o BatchMode=yes my-germany-server 'id -un; hostname; uname -m'
   ```

   Должны появиться ваш серверный логин, имя сервера и архитектура. Если видите `Permission denied (publickey)`, следующие шаги не помогут: сначала исправьте пользователя, ключ или `authorized_keys`. Если SSH доступен только под VPN, VPN понадобится и для туннеля.

## 2. Скачайте проект и установите команды Mac

**На Mac** (если `git` предлагает поставить Command Line Tools, завершите установку и повторите):

```sh
mkdir -p ~/Projects ~/.local/bin
cd ~/Projects
git clone https://github.com/draiqw/claude-security.git
cd claude-security
install -m 755 bin/claude-web bin/claude-web-vps bin/claude-route-check ~/.local/bin/
```

Если репозиторий уже скачан, вместо повторного `clone` перейдите в него. Проверьте `command -v claude-web`. Если ничего не вывелось, добавьте **один раз** в `~/.zshrc` строку `export PATH="$HOME/.local/bin:$PATH"`, затем `source ~/.zshrc`. В новой вкладке Терминала команда должна находиться. Далее считаем, что репозиторий лежит в `~/Projects/claude-security`.

## 3. Поставьте закрытый HTTP-прокси на VPS (для CLI и локального Chrome)

**На VPS**, через `ssh my-germany-server`. Нужен `sudo` или административная оболочка. Это рецепт **для нового сервера**: не заменяйте работающий прокси, если им пользуется кто-то ещё. Сначала закройте входящий `8888` в панели провайдера, поскольку пакет может запустить сервис сразу при установке.

```sh
sudo apt-get update
sudo apt-get install -y tinyproxy curl
sudo cp -p /etc/tinyproxy/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf.before-claude
sudo nano /etc/tinyproxy/tinyproxy.conf
```

Найдите директивы `Port`, `Listen`, `Allow`, `Deny`. Сохраните штатные служебные настройки пакета. Для нового выделенного экземпляра оставьте **один активный** `Port`, один `Listen` и разрешение для `127.0.0.1`, без разрешений внешним клиентам:

```text
Port 8888
Listen 127.0.0.1
Allow 127.0.0.1
```

Если в конфиге задан список `ConnectPort`, в нём должен быть `443`. Перезапустите и проверьте:

```sh
sudo systemctl enable --now tinyproxy
sudo systemctl restart tinyproxy
systemctl is-active tinyproxy
ss -ltn 'sport = :8888'
curl --noproxy '' -x http://127.0.0.1:8888 https://api.ipify.org; echo
```

Ожидается `active`, слушатель **127.0.0.1:8888** (не `0.0.0.0`, не `[::]`) и публичный адрес выхода сервера. Из интернета подключаться к этому прокси не требуется. Введите `exit`, чтобы вернуться на Mac.

## 4. Откройте туннель Mac → VPS и проверьте его отдельно от Claude

**На Mac**:

```sh
cd ~/Projects/claude-security
mkdir -p ~/Library/LaunchAgents
install -m 600 macos/local.claude.proxy.plist ~/Library/LaunchAgents/
plutil -lint ~/Library/LaunchAgents/local.claude.proxy.plist
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/local.claude.proxy.plist
```

LaunchAgent запускает SSH после входа **вашего пользователя** в macOS и перезапускает при обрыве. На Mac он слушает только `127.0.0.1:18787`; на VPS обращается к `127.0.0.1:8888`. Это **два разных localhost**. Если сервис уже зарегистрирован, не делайте повторный `bootstrap`; для применения обновлённого plist сначала `launchctl bootout "gui/$(id -u)/local.claude.proxy"`, затем `bootstrap`.

```sh
lsof -nP -iTCP:18787 -sTCP:LISTEN
curl --noproxy '' -x http://127.0.0.1:18787 https://api.ipify.org; echo
ssh my-germany-server 'curl -4fsS https://api.ipify.org; echo'
curl --noproxy '' -x http://127.0.0.1:18787 -sS -o /dev/null \
  -w 'CONNECT %{http_connect}; API %{http_code}\n' https://api.anthropic.com/v1/models
```

На однoадресном IPv4 VPS адреса должны совпасть. При IPv6 или нескольких исходящих адресах они могут отличаться: проверьте адреса сервера, прежде чем делать вывод о маршруте. `CONNECT 200; API 401` для запроса без ключа — **нормальный результат**: прокси пропустил TLS, API попросил авторизацию. Это ещё не проверяет вход в аккаунт или отправку сообщения. Параметр `--noproxy ''` в тесте не даёт настройкам `curl` обойти прокси. Эти проверки не настраивают весь Mac и не влияют на другие вкладки Chrome.

## 5. Claude Code: установка, настройки, вход и первый запрос

**На Mac** нужен официальный CLI. Если `claude --version` уже работает, переустанавливать не нужно. Иначе воспользуйтесь [официальной установкой Anthropic](https://code.claude.com/docs/en/setup). Для macOS:

```sh
curl -fsSL https://claude.ai/install.sh | bash
claude --version
```

### Как внести настройки, не потеряв свои

`~/.claude/settings.json` — пользовательские настройки; `~/.claude.json` — состояние, в том числе сведения об аккаунте. **Второй файл не редактируйте и не берите у другого человека.**

Если `settings.json` **ещё нет**, на Mac:

```sh
mkdir -p ~/.claude
# -n не заменяет уже существующий файл
cp -n ~/Projects/claude-security/examples/settings.json ~/.claude/settings.json
```

Если файл **есть**, сделайте резервную копию и откройте редактор:

```sh
cp -p ~/.claude/settings.json ~/.claude/settings.json.before-proxy
nano ~/.claude/settings.json
```

Перенесите нужные поля из [готового JSON](../examples/settings.json). В уже существующем объекте `env` добавьте ключи, а не второй объект с таким же именем; между полями JSON нужны запятые. Важные настройки:

| Поле | Для чего |
|---|---|
| `env.HTTPS_PROXY`, `env.HTTP_PROXY` | `http://127.0.0.1:18787`. HTTP — протокол **до прокси**; до сайта сохраняется HTTPS через CONNECT. SOCKS напрямую не подходит. При наличии конфликтующих строчных переменных уберите их: `https_proxy` приоритетнее `HTTPS_PROXY`. |
| `env.NO_PROXY` | `localhost,127.0.0.1,::1`: локальные обращения не отправляются в туннель. Не используйте `*`, если хотите соединяться через прокси. |
| `env.DISABLE_TELEMETRY`, `env.DISABLE_ERROR_REPORTING` | Строки `"1"`: отключение необязательных метрик и отчётов. Не анонимизация API-запроса. |
| `enableArtifact`, `deniedMcpServers` | В примере Artifacts выключены, коннектор Claude Docs запрещён. Это предпочтения, а не обязательная часть сети. |
| `remoteControlAtStartup` | `false`: не подключать терминал к Remote Control автоматически. Ручное подключение — отдельно, если доступно на вашем плане. |

Для **Claude через Anthropic** оставьте `ANTHROPIC_BASE_URL` незаданным. Это адрес API, а не адрес прокси. Не нужен ни отдельный OpenRouter-ключ, ни собственный сертификат, ни правка `/etc/hosts`.

### Вход и проверка именно приложения

```sh
claude auth login --claudeai
claude auth status
mkdir -p ~/Projects/claude-test
cd ~/Projects/claude-test
claude
```

Вход откроет браузер. Его трафик **не наследует** настройки CLI. Если нужен браузер с тем же прокси, сначала пройдите раздел 6 и завершите вход в том окне согласно подсказкам CLI. Никому не отправляйте ссылку авторизации. При первом запуске подтвердите доверие **тестовой папке**, не всему домашнему каталогу. Внутри чата откройте `/status`: ожидается `Proxy: http://127.0.0.1:18787`. Закройте статус и отправьте «Привет». Полученный ответ проверяет авторизацию и работу модели; вместе с тестами из раздела 4 это полезнее, чем один скриншот IP. Не выдавайте это за сетевой аудит всех дочерних процессов.

### Какие настройки использовались в исходном проекте

Базовый пример нарочно не копирует чужие полномочия. Исходный CLI был настроен **локально**, без проксирования вызовов инструментов: `Read`, `Edit`, `Bash` работают на Mac с правами и разрешениями текущего процесса. В `permissions.defaultMode` стояло `default`, а в `allow` был широкий список, включая Bash и инструменты MCP. В `deny` были отдельные опасные команды; это не защищает от всех способов удаления файлов. **Начните со штатных подтверждений**, а не с копии чужого списка.

Проверяли локальные MCP Context7, Playwright и персональный календарь Meetings. Для базовой схемы они не нужны; на чужом Mac календарного сервиса и его токенов не будет. `/mcp` и `claude mcp list` показывают реальные подключения. Доступность MCP ещё не означает, что его сетевые запросы идут по маршруту CLI.

Экспериментальный `env.CLAUDE_CODE_EXPERIMENTAL_CODE_MODE="1"` меняет способ вызова инструментов, не авторизацию. На протестированной версии 2.1.331 в таком сеансе не работают Remote Control, Claude in Chrome и computer use. Не включайте его, если нужен `/remote-control`. Аналогично, общий `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` блокирует Remote Control; поэтому в примере отключены только метрики и отчёты. `autoMemoryEnabled` и `autoMemoryDirectory` управляют проектными заметками, не сетью. Историю, память, файлы проекта и секреты храните отдельно от публичного репозитория.

## 6. Claude Web: локальный Chrome с отдельным профилем

Установите [Google Chrome для macOS](https://www.google.com/chrome/), если его нет в «Программах». Выполните шаги 2–4, затем **на Mac**:

```sh
claude-web
```

Откроется окно Claude без обычной панели вкладок. Войдите через него один раз. Cookies останутся в `~/Library/Application Support/Chrome-Germany`, не в основном профиле Chrome и не в CLI. Следующий запуск используeт ту же папку, пока вы не очистите данные или сервис не завершит сессию. Не открывайте этот профиль параллельно с другими параметрами: Chrome может передать окно уже работающему процессу. Если меняли параметры, завершите выделенный экземпляр и запустите команду снова.

**Что это даёт:** расширения и синхронизация в этом запуске выключены, сайт получает выход прокси, но браузер остаётся на macOS. Это не ограничение «только claude.ai». Лаунчер проверяет наличие слушателя, а не его владельца или страну выхода; для сетевой диагностики используйте шаг 4. Чтобы проверить именно браузер, в отдельной вкладке **этого же экземпляра** откройте `https://api.ipify.org` (можно запустить с тем же `--user-data-dir` и `--proxy-server`, как в скрипте `bin/claude-web`, но указать URL вместо `--app=…`). Не делайте вывод по обычному окну Chrome.

## 7. Claude Web VPS: настоящий Linux-браузер, экран на Mac

Здесь не переносится ваш профиль с Mac. На сервере создаётся другой постоянный профиль. **Граница доступа:** поставляемый `claude-web-vps` рассчитан на административный SSH-вход, способный без запроса пароля запустить `runuser`, `systemctl` и открыть приватный Unix-сокет. В текущем варианте это **SSH-пользователь root по ключу**. Команды установки через `sudo` не дают обычному SSH-пользователю этих прав при следующем запуске. Если политика VPS запрещает root SSH, не включайте парольный вход и не открывайте VNC наружу: используйте режимы 5/6 или попросите администратора адаптировать лаунчер и доступ к сокету. Сам браузер никогда не нужно запускать под root или с `--no-sandbox`.

**На Mac:** убедитесь, что `ssh -o BatchMode=yes my-germany-server 'id -u'` возвращает `0` для этого режима. Отправьте только два серверных файла:

```sh
cd ~/Projects/claude-security
ssh my-germany-server 'mkdir -p -m 700 ~/claude-security-install'
scp server/session server/chrome-vps.service my-germany-server:claude-security-install/
ssh my-germany-server
```

**На VPS**, в административной оболочке:

```sh
cd ~/claude-security-install
dpkg --print-architecture   # нужно amd64
apt-get update
apt-get install -y curl ca-certificates tigervnc-standalone-server tigervnc-tools openbox xauth x11-utils x11-xserver-utils dbus-x11
curl -fL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o google-chrome.deb
apt-get install -y ./google-chrome.deb
google-chrome-stable --version
id chrome-view >/dev/null 2>&1 || useradd --system --user-group --create-home --home-dir /var/lib/chrome-view --shell /usr/sbin/nologin chrome-view
chmod 700 /var/lib/chrome-view
install -d -m 700 -o chrome-view -g chrome-view /var/lib/chrome-view/.vnc
install -D -m 755 session /usr/local/libexec/chrome-vps-session
install -m 644 chrome-vps.service /etc/systemd/system/
systemctl daemon-reload
exit
```

**На Mac:** запустите `claude-web-vps`. При первом запуске терминал попросит придумать пароль VNC: используйте отдельный случайный пароль длиной 8 символов, сохраните его в менеджере паролей. Ввод не отображается — это нормально. На `Verify:` повторите его. На `Would you like to enter a view-only password?` ответьте `n`, если не даёте отдельный просмотр другому человеку. Это **не пароль от Claude, Mac или SSH**. Закрытие краткой SSH-сессии после настройки пароля нормально. Далее откроется Screen Sharing; введите свой пароль VNC и войдите на сайт в удалённом Chrome.

Экран передаётся так: **Mac:15947 → SSH → `/run/chrome-view/view.sock` → TigerVNC**. Непосредственно к порту VNC в интернете подключаться не нужно. Профиль Chrome и cookies сохраняются в `/var/lib/chrome-view/profile`; администратор VPS имеет к ним доступ. Домашняя папка Mac не примонтирована, но не считайте общий буфер обмена защищённым. Сайт видит удалённый Linux-браузер, а не Mac; авторизованный аккаунт остаётся узнаваемым.

**Проверка:** внутри удалённого Chrome откройте `https://api.ipify.org`; сравните с выходом VPS. Из Терминала Mac проверьте службу и экран:

```sh
ssh my-germany-server 'systemctl is-active chrome-vps; ss -lx | grep /run/chrome-view/view.sock'
ssh my-germany-server 'runuser -u chrome-view -- env DISPLAY=:47 XAUTHORITY=/run/chrome-view/Xauthority xdpyinfo | grep dimensions'
```

Ожидается `active`, Unix-сокет и **1920×1080**. Если клиент изменил размер, используйте команду `xrandr` из [README](../README.md). Закрытие окна Screen Sharing — не то же, что остановка Chrome. Для остановки браузера **без удаления профиля**: `claude-web-vps --stop`; для повторного входа: `claude-web-vps`.

## 8. Если что-то не работает

| Симптом | Что проверить первым |
|---|---|
| `command not found` | `command -v claude`, `command -v claude-web`, `command -v claude-web-vps`. Это три разные команды. Откройте новый терминал после изменения PATH. |
| `Connection refused` на `18787` | `launchctl print "gui/$(id -u)/local.claude.proxy"`, затем `ssh -o BatchMode=yes my-germany-server true`. Проверьте, что SSH-ключ разблокирован и порт не занят другим приложением. |
| `administratively prohibited` | Сервер SSH не разрешил перенаправление портов либо Unix-сокетов. Это серверная политика; согласуйте её с администратором. |
| `407` или `403` | Проверьте конфигурацию прокси и источник ответа. Ошибка прокси, ответ API и отсутствие подписки — разные случаи. `401` без ключа в диагностике ожидаем, в авторизованном чате — нет. |
| `/status` не показывает прокси | Перезапустите CLI после изменения файла, проверьте синтаксис JSON и конфликтующие переменные окружения. `uds:/…` — локальный сокет, не IP. |
| Запрос доверия к папке возвращается | Запускайте из отдельного каталога проекта. Для корня домашней папки CLI может доверять только на время сессии. Не отключайте все разрешения ради этого окна. |
| VNC просит пароль при каждом просмотре | Используйте первый пароль VNC, а не пароль Claude. Если забыли: на сервере администратор запускает `runuser -u chrome-view -- tigervncpasswd /var/lib/chrome-view/.vnc/passwd`, затем `systemctl restart chrome-vps`. |
| VNC показывает чёрное окно | `ssh my-germany-server 'systemctl status chrome-vps --no-pager; journalctl -u chrome-vps -n 30 --no-pager'`. Проверьте место на диске, архитектуру и наличие пакета Chrome. Не публикуйте необработанный журнал. |
| Страница на VPS открывается, но CLI не работает | Режим VNC не пользуется туннелем Tinyproxy. Проверьте разделы 4 и 5 отдельно. |

## 9. Как откатить без потери аккаунта или профилей

1. **VNC:** на Mac `claude-web-vps --stop`. Это не удаляет серверные cookies или профиль.
2. **CLI:** удалите из `~/.claude/settings.json` только добавленные вами прокси-поля или восстановите резервную копию, если с момента её создания не было других изменений. Перезапустите CLI. `claude auth logout` нужен только если хотите отдельно выйти из аккаунта.
3. **Туннель:** на Mac `launchctl bootout "gui/$(id -u)/local.claude.proxy"`. Уберите `~/Library/LaunchAgents/local.claude.proxy.plist`, чтобы не было запуска при следующем входе. Не останавливайте Tinyproxy на общем сервере, не проверив других клиентов.
4. **Команды Mac:** при желании удалите только `~/.local/bin/claude-web` и `~/.local/bin/claude-web-vps`. Это не удаляет `claude` и профиль Chrome-Germany. Проектные файлы и `memory/` для отката не трогайте.

Технические выводы, границы проверок и ссылки на документацию Anthropic — в [README](../README.md#что-проверяли-и-чего-не-утверждаем).
