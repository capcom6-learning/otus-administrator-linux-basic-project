# Проектная работа

Тема: развертывание веб-приложения с балансировкой нагрузки, резервным копированием базы данных и мониторингом.

# Ход работы

Работа выполняется на CentOS 7 со следующим набором серверов:

1. Frontend-сервер на базе Nginx.
2. Backend-сервера в количестве 2 шт. на базе Apache + PHP.
3. Сервер баз данных на основе MariaDB.
4. Сервер репликации базы данных MariaDB с резервным копированием.
5. Сервер мониторинга на базе Prometheus + Grafana.

Данные сервера развернуты у облачного провайдера с заранее прописанным ключом доступа по SSH для пользователя root. Для настройки серверов используется Ansible.

## Формирование файла инвентаря

Все сервера были сгруппированы по своему назначению и прописаны в файл hosts для дальнейшего использования с Ansible. Были выделеные следующие группы:

* webservers - backend-сервера;
* dbservers - основной MySQL-сервер, было условлено, что данная группа должна содержать ровно 1 сервер для корректной настройки репликации;
* dbslaves - реплики основного MySQL-сервера;
* lbservers - frontend-сервер;
* monitoring - сервер мониторинга.

Для групп `dbservers` и `dbslaves` непосредственно в файле `hosts` указано значение переменной server_id. Указание данной переменной в общем файле вместо использования `hosts_vars` позволяет иметь возможность визуального контроля уникальности используемых server_id.

## Формирование ролей

Для перечисленных ранее серверов были выделены следующие роли:

* common - общая для всех серверов роль, выполняющая базовые настройки;
* base-apache - установка и настройка Apache + PHP;
* base-db - установка и настройки MariaDB;
* slave-db - действия по развертыванию реплики MySQL-сервера;
* master-db - действия по переводу Slave в Master;
* nginx - установка и настройка балансировщика нагрузки на базе Nginx;
* web - развертывание веб-приложения из репозитория;
* web-db - создание базы данных приложения;
* monitoring - установка и настройка Prometheus + Grafana;
* monitoring-node - установка экспортеров для Prometheus.

Данные роли были назначены группам серверов следующим образом:

* все сервера:
    * common;
    * monitoring-node.
* dbservers:
    * base-db;
    * web-db;
    * master-db.
* dbslaves:
    * base-db;
    * slave-db.
* webservers:
    * base-apache;
    * web.
* lbservers:
    * nginx.
* monitoring:
    * monitoring.

Далее рассмотрены ключевые моменты отдельных ролей.

### Роль common

Цель данной роли выполнить общие настройки сервера, в частности:

* установить репозиторий epel-release;
* разрешить неограниченный доступ к серверам в рамках виртуальной сети, которая выделена в переменную network в файле group_vars/all;
* отключить SELinux для упрощения развертывания. Ряд ролей уже содержит применение настроек для случая включенного SELinux, но требуется дополнительная работа в данном направлении.

### Роль monitoring-node

Данная роль выполняет установку на сервер Node Exporter и сопутствующие настройки:

* создает пользователя prometheus-exporter для ограничения прав Node Exporter;
* проверяет наличие уже установленного Node Exporter, чтобы не выполнять повторную установку;
* при отсутствии Node Exporter на сервере выполняестя копирование инсталляционного скрипта и его запуск;
* в конечном счете регистрируется юнит systemd и запускается сервис.

Для установки используется шаблон простого скрипта с переменной для версии Node Exporter:

```bash
#!/bin/bash

cd /tmp
# Скачаем архив с node exporter
curl -LO https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz
# Распакуем в текущую директорию
tar xzvf node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz
# Копируем исполняемый файл в общесистемный каталог
cp node_exporter-{{ node_exporter_version }}.linux-amd64/node_exporter /usr/local/bin/

rm -rf node_exporter-{{ node_exporter_version }}.linux-amd64
```

Минусом такого подхода к проверки наличия Node Exporter является невозможность обновления, посколкьу задача "Check for Node Exporter binary" проверяет лишь наличие исполняемого файла, но не проверяет версию. В итоге изменение переменной с версией не приводит к обновлению Node Exporter. Это задача для дальнейшей проработки.

### Роль base-db

Данная роль выполняет установку MariaDB и ее настройку, общую для основного сервера и реплики:

* импортирует ключ и копирует настройки репозитория указанной в переменных версии MariaDB;
* устанавливает основные пакеты MariaDB, а также библиотеку для Python для работы с MySQL из Ansible;
* создает конфигурационный файл сервера:

```conf
[mysqld]
# set server_id
server-id		        = {{ server_id }}
# optimize memory usage
{% if 'dbservers' in group_names %}
innodb_buffer_pool_size	= {{ (ansible_memtotal_mb * 0.8) | int }}M
{% else %}
innodb_buffer_pool_size	= {{ (ansible_memtotal_mb * 0.5) | int }}M
read_only               = 1
{% endif %}

# set binlog filename prefix
log_bin                 = mysql-bin
# set binlog format
binlog_format           = mixed
# set binlog expire days
expire_logs_days        = {{ mysql_binlog_expire }}
# set compression for binlog
log_bin_compress        = ON
```

Через переменные задается server_id и параметры двоичного журнала для работы репликации. Также задается объем выделенной оперативной памяти. Для основного сервера выделяется 80% от общего объема, а на репликах - 50%. Это обосновано тем, что на репликах помимо непосредственно работы сервера базы данных будет производится резервное копирование, потенциально с использованием сжатия, что потребует свободной оперативной памяти.

В дальнейшем при определении объема оперативнйо памяти для сервера баз данных стоит учитывать общий объем доступно памяти. Так на системах с малым объемом памяти (< 2 GB) при выделении 80% под сервер базы данных может возникнуть нехватка памяти под ОС.

В продолжение настройки выполняется еще ряд действий:

* задаются права доступа по-умолчанию для новых файлов и каталогов баз данных путем указания в файле umask.conf. Это необходимо для корректной работы резервного копирования, поскольку по-умолчанию доступ к каталогам баз данных разрешен только пользователю mysql, а для работы резервного копирования также требуется доступ для группы mysql;
* запускается сервис MariaDB;
* устанавливается пароль для пользователя root и создается файл конфигурации клиента .my.cnf для системного пользователя root;
* удаляются тестовые базы данных, анонимные пользователи и удаленный доступ к базе данных от имени пользователя root;
* создаются пользователи для репликации и резервного копирования с необходимыми правами.

Поскольку пароли для создаваемых пользователей хранятся в переменных, то хранение их в открытом виде не рекомендуется. В связи с этим они былди предварительно зашифрованы с применением ansible-vault:

```
ansible-vault encrypt_string --ask-vault-password '***' --name 'mysql_root_password'
```

### Роль web-db

Данная роль выполняет развертывание базы данных приложения на основном сервере. Также создается пользователь базы данных приложения согласно соответствующим переменным.

### Роль slave-db

В рамках данной роли выполняется 2 основных действия:

* настройка репликации, если она не была настроена ранее;
* настройка резервного копирования.

Рассмотрим данные действия подробнее.

### Роль master-db

Выполняет перевод slave-сервера в master. Для этого проверяется текущее состояние и, если данный сервер является репликой, то выполняется перевод в master.

#### Настройка репликации

Перед настройкой репликации проводится проверка текущего состояния репликации. Если репликация уже настроена, то данной действие пропускается. Настройка репликации вынесена в отдельный файл `init_replication.yml`.

В рамках инициализации репликации выполняются следующие действия:

* путем делегации действий на основном сервере MariaDB с помощью утилиты mariabackup создается резервная копия с указанием позиции двоичного журнала;
* данная копия передается на настраиваемую реплику. В данном случае это происходит через локальный компьютер, что, в общем случае, не эффективно, а потому является основанием для дальнейших доработок;
* полученная резервная копия разворачивается на реплике, настраиваются права доступа к файлам баз данных;
* запускается процесс репликации с использованием GTID, считанного из файла `xtrabackup_binlog_info` из состава резервной копии.

#### Настройка резервного копирования

Для реализации резервного копирования по расписанию создается отдельный пользователь ОС с логином backup, входящий в группу mysql для возможности доступа к файлам БД.

Непосредственно резервное копирование выполняется скриптом `mysql_backup.sh`, созданном на основании шаблона:

```bash
#!/bin/sh

NOW=$(date +"%Y-%m-%d")

find {{ mysql_backup_location }} -maxdepth 1 -ctime +{{ mysql_backup_expire }} -type d -exec rm -rf {} \; \
    && mkdir -p {{ mysql_backup_location }}/${NOW} \
    && mariabackup --backup --target-dir={{mysql_backup_location}}/${NOW} \
    && mariabackup --prepare --target-dir={{mysql_backup_location}}/${NOW}
```

Данный скрипт помещается в задачу cron с ежедневным выполнением, что позволит иметь полные резервные копии за указанное в переменных количество дней.

### Роль base-apache

В рамках данной роли выполняется установка связки Apache + PHP.

Поскольку веб-приложение планируется разворачивать из Git-репозитория, то в рамках файла конфигурации Apache запрещаем доступ к каталогу .git:

```conf
<DirectoryMatch "^/.*/\.git/">
    Order deny,allow
    Deny from all
</DirectoryMatch>
```

### Роль web

В рамках данной роли выполняется развертывание веб-приложения. Для демонстрационных целей выбрано не конкретное веб-приложение, а PHP-фреймворк CodeIgniter. Такой выбор сделан из расчета, что развертывание всех приложений на данной фреймворке будет иметь сходные шаги.

### Роль nginx

Выполняет установку nginx и добавление ранее настроенных backend-серверов в файл конфигурации:

```conf
    upstream backend {
    {% for host in groups.webservers %}
        server {{ hostvars[host].ansible_all_ipv4_addresses | ansible.netcommon.ipaddr(network) | first }}:80;
    {% endfor %}
    }
```

При этом используются внутренние адреса серверов благодаря фильтру `ansible.netcommon.ipaddr(network)`.

Далее выполняется запуск NGinx и прописывается сервис в firewalld для возможности доступа извне.

### Роль monitoring

В рамках данной роли выполняется установка и базова настройка Prometheus и Grafana. Установка Prometheus выполняется по той же схеме, что и Node Exporter - с помощью готового скрипта.

После применения данной роли Grafana доступна на порту 3000 для дальнейшей настройки.

В дальнейшем, используя REST API Grafana, можно реализовать полностью автоматизированную настройку путем импорта готовых панелей из JSON.

## Настройка серверов

После формирования инвентаря и необходимых ролей достаточно запустить Ansible на выполнение:

```bash
ansible-playbook -i hosts site.yml -u root --ask-vault-pass
```

Далее вводим пароль от защищенных значений и ожидаем завершения работы Ansible. В конечном счете имеет настроенные согласно испходной задаче сервера с развернутым веб-приложением.

## Аварийное восстановление

Для аварийного восстановления достаточно запустить пустой сервер с CentOS 7, указать его в файле инвентаря Ansible, после чего повторить запуск Ansible. Данный подход сработает со всеми серверами за исключением основного сервера базы данных, поспольку при обычном запуске там будет развернута чистая БД и будет нарушена репликация.

В случае восстановления основного сервера база данных, то самый оптимальный вариант - переводж существующего slave-сервера в master. Для этого достаточно в файле инвентаря перенести запись с адресом slave-сервера в группу `dbservers`.

В дальнейшем можно рассмотреть восстановление основного сервера баз данных из локальной резервной копии, передвая путь к ней из командной строки Ansible, загружая на удаленный сервер и копируя ее в каталог данных MariaDB.

# Итоги

Таким образом, на базе Ansible реализовано развертывание полноценной инфраструктуры для веб-приложения с репликацией и резервным копированием базы данных. Аварийное восстановление при этом фактически заключается в повторном запуске Ansible с указанием чистых серверов в файле инвентаря.

В рамках дальнейшей работы над проектом стоит рассмотреть:

1. Использование Terraform для подготовки серверов (проведена первичная работа).
2. Автоматическое формирование файла инвентаря Ansible на основе состояния Terraform.
3. Оптимизацию процесса развертывания реплик базы данных, исключив загрузку резервной копии через локальный компьютер.
4. Использование сжатия и инкрементального резервного копирования базы данных.
5. Использование распределенной ФС (например, GlusterFS) для хранения данных пользователей и синхронизации их между backend-серверами.
6. Развертывание основного сервера базы данных из локальной резервной копии.
7. Автоматизацию настройки Grafana, в т.ч. добавление панелей по средствам API.