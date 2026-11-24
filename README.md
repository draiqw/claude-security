# Claude Security: Mac и немецкий VPS

Два способа открыть **веб-чат** и отдельная настройка **Claude Code CLI**. Выбирайте, кому доверить браузерную сессию. Ни один режим не делает пользователя анонимным.

| Запуск | Где выполняется | Что получает сайт | Где хранится профиль |
|---|---|---|---|
| `claude-web` | Chrome на Mac, отдельное окно приложения | Запрос через прокси приходит с VPS; браузер остаётся macOS | Mac, Chrome-Germany |
| `claude-web-vps` | Chrome на Linux, Mac показывает экран | Linux-браузер и сетевой адрес VPS | VPS, /var/lib/chrome-view/profile |
| `claude` | CLI и его Read/Edit/Bash на Mac | API-запросы через настроенный CONNECT-прокси | CLI-состояние на Mac, независимо от Chrome |

### 1. Общие условия

Примеры используют SSH-алиас `my-germany-server` из вашего ~/.ssh/config. Нужен вход по SSH-ключу в пакетном режиме. Для установки системных файлов и приведённого VPS-лаунчера нужен администратор сервера; сам Chrome работает **не под root**. Не копируйте приватные ключи на сервер. Серверная часть рассчитана на Ubuntu 24.04 x86_64. На Mac нужны Google Chrome (только для локального режима), OpenSSH и Screen Sharing. Скопируйте оба файла из bin/ в ~/.local/bin/ и добавьте этот каталог в PATH.

### 2. Локальный браузер и CLI: CONNECT через SSH

На VPS установите Tinyproxy; для нового экземпляра в /etc/tinyproxy/tinyproxy.conf задайте `Listen 127.0.0.1`, `Port 8888` и `Allow 127.0.0.1`, затем перезапустите сервис. Не открывайте 8888 в интернет. На существующем сервере сначала проверьте ACL, firewall и других клиентов — смена Listen может их отключить.

На Mac из корня репозитория:


```sh
mkdir -p ~/Library/LaunchAgents ~/.local/bin
install -m 755 bin/claude-web bin/claude-web-vps ~/.local/bin/
install -m 600 macos/local.claude.proxy.plist ~/Library/LaunchAgents/
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/local.claude.proxy.plist
curl --noproxy '' -x http://127.0.0.1:18787 https://ipinfo.io/country
claude-web
```

Схема: Chrome/CLI → 127.0.0.1:18787 → SSH → 127.0.0.1:8888 на VPS → сайт. VPN на Mac может изменить маршрут до VPS, но выход прокси остаётся серверным. Без работающего туннеля лаунчер не открывает локальный Chrome. Это не системный kill switch. App mode убирает вкладки, но **не** запрещает другие сайты. Для остановки туннеля: `launchctl bootout "gui/$(id -u)/local.claude.proxy"`.

Для CLI объедините **нужные ключи** из [examples/settings.json](examples/settings.json) с ~/.claude/settings.json; не заменяйте настройки целиком. Для прямого Anthropic через прокси не меняйте ANTHROPIC_BASE_URL. Перезапустите CLI, проверьте /status → Proxy и отдельно claude auth status. Вход и cookies браузера не равнозначны авторизации CLI. Пример отключает телеметрию, отчёты об ошибках, Docs и Artifacts; не переносит личные MCP, токены и широкие разрешения инструментов. Remote Control не включается автоматически. Общий флаг отключения необязательного трафика несовместим с Remote Control; экспериментальный Code Mode также несовместим с ним. Сетевой маршрут каждого MCP, Bash и браузера при входе надо проверять отдельно.

### 3. Удалённый браузер: VNC только внутри SSH

На VPS установите официальный пакет google-chrome-stable для Linux amd64 и зависимости: tigervnc-standalone-server, tigervnc-tools, openbox, xauth, x11-utils, x11-xserver-utils, dbus-x11. Скопируйте каталог server/ на VPS. На новом сервере выполните от администратора из каталога с server/:

```sh
id chrome-view >/dev/null 2>&1 || useradd --system --user-group --create-home --home-dir /var/lib/chrome-view --shell /usr/sbin/nologin chrome-view
chmod 700 /var/lib/chrome-view
install -d -m 700 -o chrome-view -g chrome-view /var/lib/chrome-view/.vnc
install -D -m 755 server/session /usr/local/libexec/chrome-vps-session
install -m 644 server/chrome-vps.service /etc/systemd/system/
systemctl daemon-reload
```

На Mac запустите **claude-web-vps**. При первом запуске задайте пароль VNC и ответьте **n** на запрос отдельного view-only пароля, если просмотр другим людям не нужен. Подключение: Screen Sharing → локальный порт 15947 → SSH → закрытый Unix-сокет TigerVNC. TCP-порт VNC на VPS не требуется. Войдите в сайт на VPS один раз, не переносите cookies с Mac. Чтобы остановить браузер и туннель, сохранив профиль: **claude-web-vps --stop**.

**Экран:** 1920×1080 (16:9) задаётся в server/session. Чтобы поменять разрешение без перезапуска текущего Chrome, на сервере: `runuser -u chrome-view -- env DISPLAY=:47 XAUTHORITY=/run/chrome-view/Xauthority xrandr --output VNC-0 --mode 1920x1080`. Масштаб просмотра на Mac и разрешение удалённого экрана — разные настройки.

### Что проверяли и чего не утверждаем

- Проверили CONNECT до API: 200 от прокси и 401 от API без ключа. Это проверка сети, не авторизации. Отдельно отправили один авторизованный запрос Claude Code, разрешив процессу сетевой выход только на локальный порт туннеля: получили ответ. Проверка страны через тот же прокси вернула DE. Обычная сессия CLI не наследует это тестовое ограничение.
- Проверили соединение VNC через SSH и запуск Chrome под chrome-view. Администратор VPS контролирует хранилище браузера. Буфер обмена не считается изолированным в этой конфигурации. Строгого списка разрешённых сайтов здесь нет.
- В тестовом запросе CLI 2.1.329 к локальному приёмнику оставались заголовки ОС, архитектуры и версия клиента, а также поля идентификаторов сессии/устройства даже с отключённой телеметрией. Отключение атрибуции убрало блок атрибуции, отключение автопамяти убрало путь из связанной с памятью части промпта. Это наблюдение одной версии и конфигурации, не аудит всех соединений. CONNECT не переписывает зашифрованное содержимое запросов. Путь или имя устройства могут попасть в текст результатов инструментов.
- uds:/… в /status — локальный Unix-сокет, не внешний IP. Доверие к рабочей папке и разрешения инструментов не управляют прокси. IP и ID сеанса — не доказательство физического местоположения или требований KYC.
- Не публикуйте ~/.claude.json, реальные настройки MCP с секретами, cookies, сырые дампы трафика, транскрипты, пароли VNC, ключи и архивы конфигурации. В репозитории только скрипты и обезличенный пример.

Документация Anthropic: [сеть и прокси](https://code.claude.com/docs/en/network-config), [использование данных](https://code.claude.com/docs/en/data-usage), [переменные окружения](https://code.claude.com/docs/en/env-vars), [Remote Control](https://code.claude.com/docs/en/remote-control).
