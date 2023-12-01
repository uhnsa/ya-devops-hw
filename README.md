Как деплоил сервис

Всё началось с простого запуска ./bingo. Приложение со мной поздоровалось.

Тогда запустил его флагом -h, чтобы получить какую-то помощь.

Из предложенных команд попробовал запустить команду с конфигом по умолчанию и текущим. Команда /bingo print_current_config выдала ошибку.

По итогам 3-й лекции решил воспользоваться командой strace. Она уже показала местоположение конфига

openat(AT_FDCWD, "/opt/bingo/config.yaml", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)

После создания директории и конфига со своим email я попробовал запустить сервер ./bingo run_server.
Но получил ошибку:
panic: failed to build logger

goroutine 1 [running]:
bingo/internal/logger.New({0xc000132780, 0x23}, {0xd34748, 0xd})

Видимо что-то с логами. Поэтому тут пошел ещё раз за помощью к strace.
openat(AT_FDCWD, "/opt/bongo/logs/1fd892b4a8/main.log", O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC, 0666) = -1 ENOENT (No such file or directory)

Нужно было создать директорию /opt/bongo/logs/1fd892b4a8/.

После создания директории сервер стал запускаться, но свалился с подключением к БД.

Тогда я локально поставил postgresql. Пользователю присвоил пароль и попробовал подготовить БД с помощью ./bingo prepare_db.

