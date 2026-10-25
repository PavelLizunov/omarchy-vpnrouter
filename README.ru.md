# VPNRouter для Omarchy Quattro

Нативная QML-панель и виджет VPNRouter внутри оболочки Omarchy.
**Черновик разработки; полный паритет функций Linux пока не подтверждён.**

[English](README.md) · [Релизы](https://github.com/PavelLizunov/omarchy-vpnrouter/releases) (релиза плагина пока нет) · [Текущий статус](plans/current-status.md)

## Установка

Нужны Omarchy Quattro и пакет Arch `vpnrouter-headless`.
См. [инструкцию пакета backend](https://github.com/PavelLizunov/VPNRouter/blob/dsh/omarchy-mvp-2026-10-22/packaging/arch/README.md).
Выполните из репозитория на проверенном коммите:

Перезапуск оболочки останавливает backend VPNRouter и разрывает
активное соединение VPNRouter.

```bash
id=io.github.pavellizunov.vpnrouter
plugin_dir="$HOME/.config/omarchy/plugins/$id"
mkdir -p "$plugin_dir"
git archive HEAD | tar -x -C "$plugin_dir"
omarchy plugin validate "$plugin_dir"
omarchy-shell shell rescanPlugins
omarchy plugin enable "$id" --section right
omarchy restart shell
omarchy plugin list --json
```

Используйте обычный каталог. Если локального payload нет, обёртка запускает
системный backend. Копирование файлов не устанавливает sing-box и не делает VPN
доступным само по себе. Необязательная [установка локального backend](docs/guide.ru.md#установка-и-настройка)
требует Python 3 и доверенной publish-директории; setup не скачивает бинарники.

## Использование

Нажмите значок в панели, чтобы открыть главную. Добавьте подписку или импортируйте
серверы, выберите сервер и нажмите «Подключить», когда backend разрешит подключение.
Правая кнопка на значке переключает соединение, средняя обновляет статус.
Разделы панели содержат серверы, подписки, приложения, правила маршрутизации,
профили, пользовательские конфигурации, настройки, диагностику и свободный пул.

Переключатель языка выбирает EN/RU/AUTO. Tab переносит фокус, Escape закрывает
панель. В многострочных редакторах отправка выполняется через Ctrl+Enter.
Базовый Test и HTTP Verify через прокси — разные операции; отсутствие значения
задержки не означает, что сервер недоступен.

[Руководство](docs/guide.ru.md) описывает команды открытия разделов, параметры,
установку, обновление, удаление и тесты; [архитектура](plans/implementation.md) — владельцев компонентов.

## Ограничения

Kill switch и DNS lockdown на Linux недоступны. Элементы DNS показывают сохранённую
конфигурацию, а не активное состояние ядра. Поиск работает по загруженным страницам;
списки загружаются по 100 строк. Технические сообщения backend могут оставаться
на исходном языке.

Автоматические проверки используют инертные ответы backend и offscreen-адаптер
host. Они не подтверждают работу живой оболочки, маршрутизацию VPN-трафика,
защиту от утечек или полный паритет функций. Открытые ограничения — в
[текущем статусе](plans/current-status.md).

## Лицензия

[GPL-3.0](LICENSE), с сохранением происхождения из [VPNRouter](https://github.com/PavelLizunov/VPNRouter).
