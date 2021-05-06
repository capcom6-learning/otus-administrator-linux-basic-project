## Изменения

### Изменения от 06 мая 2021 г

В рамках запрошенных доработок в части синхронизации пользовательских данных между backend-серверами и сохранением сессии пользователя реализовано следующее:

* алгоритм распределения запросов на стороне nginx изменен на ip_hash для сохранения сессии пользователя для случая хранения сессий в файлах;
* для синхронизации файлов пользователей развернут кластер GlusterFS между backend-серверами.

Также добавлена задача формирования файла /etc/hosts из файла инвентаря на основании адресов в локальной (приватной) сети:

```jinja2
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

{% for item in groups.all %}
{{ hostvars[item].ansible_all_ipv4_addresses | ansible.netcommon.ipaddr(network) | first }} {{ hostvars[item].ansible_hostname }}
{% endfor %}
```