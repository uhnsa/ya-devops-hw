Как деплоил сервис

Всё началось с простого запуска ./bingo. Приложение со мной поздоровалось.

Тогда запустил его флагом -h, чтобы получить какую-то помощь.

Из предложенных команд попробовал запустить команду с конфигом по умолчанию и текущим. Команда /bingo print_current_config выдала ошибку.

По итогам 3-й лекции решил воспользоваться командой strace. Она уже показала местоположение конфига

openat(AT_FDCWD, "/opt/bingo/config.yaml", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)

