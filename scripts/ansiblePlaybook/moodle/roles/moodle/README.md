moodle
=========

Install moodle

Role Variables
--------------

    db_host: "127.0.0.1"
    db_pwd_root: "mysql-root-pass"
    db_name: 'moodle'
    db_username: 'moodleAdmin'
    db_password: 'moodle-db-pass'

    moodle_domain: "your-moodle.edu"
    moodle_path: "/opt/moodle"
    moodle_src: "{{ moodle_path }}/src"
    moodle_docs: "{{ moodle_path }}/moodleDocs"
    moodle_version: "MOODLE_30_STABLE"
    moodle_user: "moodle"

Dependencies
------------

Roles dependecies:
- debops.pki
- debops.mysql
- debops.php5
- debops.nginx

Variables to setup:

- mysql
- php5
- nginx

Example Playbook
----------------

- hosts: mymoodle
  roles:
  - { role: krahser.moodle, moodle_version: "MOODLE_30_STABLE" }


License
-------

GPL-3

Contributors
------------

- [Nadav Kavalerchik](https://github.com/nadavkav)

Author Information
------------------

Comments and pull request are welcome
