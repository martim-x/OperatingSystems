# Сырые кадры съёмки ЛР3 (Windows)

Сняты 2026-10-25 на `User-6d4ec851@192.168.31.23` (Windows 11 ARM, VMware Fusion).
Источник — `C:\lab3_sync\shots\`, драйвер `lab3/windows/tools/run_lab.ps1`, лог `C:\lab3_sync\driver.log`.

Здесь лежит **всё, что было снято**, включая черновики и отбракованные кадры. 32 файла, ~20 МБ.
Кадры, прошедшие приёмку, перенесены в `lab3/windows/скрины/уровень_*/` под финальными именами.

## Финальные (уже в скрины/)

| Файл здесь | Куда перенесён |
|---|---|
| `01_build.png` | `уровень_4-5/task01_сборка.png` |
| `02_lab03x_arg.png` | `уровень_4-5/task02_lab03x_аргумент.png` |
| `03_lab03x_env.png` | `уровень_4-5/task03_lab03x_окружение.png` |
| `04_lab03x_err.png` | `уровень_4-5/task04_lab03x_ошибка.png` |
| `05_lab03a.png` | `уровень_4-5/task05_lab03a_три_процесса.png` |
| `06_lab03b.png` | `уровень_4-5/task06_lab03b_переменные_окружения.png` |
| `07_lab03c.png` | `уровень_4-5/task07_lab03c_список_процессов.png` |
| `08_lab03d_client.png` | `уровень_7-8/task08_lab03d_клиент.png` |
| `09_lab03d_server3.png` | `уровень_7-8/task09_lab03d_сервер_3.png` |
| `10_lab03d_server4.png` | `уровень_7-8/task10_lab03d_сервер_4.png` |
| `11_lab03hello.png` | `уровень_9-10/task11_startupinfo_hello.png` |
| `12_lab3_ls.png` | `уровень_9-10/task12_список_exe.png` |

## Черновики и отбракованные

| Файл | Почему не пошёл |
|---|---|
| `00_probe.png` | пробный кадр драйвера (проверка, что съёмка вообще работает) |
| `20_procexp.png` | попытка снять Process Explorer под драйвером: окно не найдено, `window not found` |
| `05_lab03a_three.png` | `Lab-03a.exe 3`: живых дочерних только два, и это консольный вывод, а не список процессов |
| `06_lab03b_local.png` | дубль варианта с локальной `ITER_NUM` |
| `07_lab03c_tree.png` | дубль списка процессов |
| `f_tree.png`, `f_handles.png` | ранние попытки дерева процессов / дескрипторов |
| `g08_procexp.png` | Process Explorer без нижней панели handles, перекрыт Диспетчером задач |
| `g10_taskmgr_proc.png` | Диспетчер задач чистый, но процессы `Lab-03*` в момент съёмки не запущены |
| `g11_taskmgr_details.png` | то же, вкладка «Подробности» |
| `g15_pipe.png` | нет нижней панели handles → дескриптор канала не виден |
| `g16_handles.png` | то же, дескрипторы процессов не видны |
| `p_tree.png`, `p_handles.png`, `q_tree.png`, `q_handles.png`, `v_tree.png`, `v_handles.png`, `w_tree.png`, `w_handles.png` | серия попыток настроить нижнюю панель и фокус; ни одна не дала нужной строки `File`/`Process` |

## Чего здесь нет

7 кадров, которые остались плейсхолдерами в репозитории, — их ещё предстоит снять:
`уровень_4-5/task09_cmd.png`, `task10_taskmgr.png`, `task11_three_proc.png`, `task15_procexp_pipe.png`,
`task16_procexp_handles.png` и `уровень_7-8/task15_procexp_pipe.png`, `task16_procexp_handles.png`.

Задание на досъёмку — `lab3/windows/ТЕХДОЛГ_СКРИНЫ.md`.
