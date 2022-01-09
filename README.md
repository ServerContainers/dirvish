# Docker Dirvish Backup System (servercontainers/dirvish) [x86 + arm]

dirvish on debian

## Versioning

You'll find all images tagged like `d11.2-dv1.2.1-2.1` which means `d<debian version>-dv<dirvish version (with some esacped chars)>`.
This way you can pin your installation/configuration to a certian version. or easily roll back if you experience any problems
(don't forget to open a issue in that case ;D).

The `latest` version will be updated/released after I managed to test a new pinned version in my production environment.
This way I can easily find and fix bugs without affecting any users. It will result in a way more stable container.

## Changelogs

* 2022-01-09
    * new build script
    * version tagging
    * update to debian `bullseye`
* 2021-07-27
    * fix how report fetches latest backup of the day
    * fix `\r` windows linebreaks in `master.conf`
* 2021-03-19
    * configure return-address for status mail
* 2021-03-17
    * multiarch build
    * rewrite to debian:buster

## What is it

This Dockerfile (available as ___servercontainers/dirvish___) gives you a Dirvish Backup System in a container.

- Backup System in Container
    - _runs at a specific time in infinite loop_
- Standalone Backup
    - _container exits after backup is done_
    - good if triggered from external cronjob etc.

For Configuration of the Server you use environment Variables and volume files.

It's based on the [debian](https://registry.hub.docker.com/_/debian) Image

View in Docker Registry [servercontainers/dirvish](https://registry.hub.docker.com/u/servercontainers/dirvish/)

View in GitHub [ServerContainers/dirvish](https://github.com/ServerContainers/dirvish)

## Environment variables

- STANDALONE
    - if this variable is set to any value the container stops after the backup is done
    - default not set

- TZ
    - specify the timezone inside the container
    - default _Europe/Berlin_

- CRONTIME
    - overwrite default crontime with your one
    - default _30 4 * * *_

- MAIL_RECIPIENTS
    - list of mail addresses to recieve status mail after backup
    - e.g.: `joe@company.tld admin@company.tld supervisor@company.tld`

- RETURN_ADDRESS
    - sender of status email
    - default: `noreply@dirvish.backup.sys`
    - e.g.: `noreply@backupsystem.company.tld`

## Volumes

- /config
    - this is where the container looks for:
        - master.conf (dirvish main configuration file - see example or official manual)
        - id_rsa (ssh private key to connect to backup-clients/servers)
            - _don't forget to specify it inside master.conf_
        - _ida_rsa.pub (ssh public key - not needed - only on clients)_
- /backups
    - this is where the container stores backups and looks for backup-client configurations
    - _default layout beneath this folder:_ ___bank/backup/dirvish/default.conf___

_Take a look at the GitHub Repo, you'll find a example there._

## Cheat Sheet

### SSH Key generation

To connect to your hosts, you need to install a ssh keypair on them. This keypair should be moved to the config folder of the container. __Don't forget to specify it in the master.conf as well!__

To generate a keypair just execute `ssh-keygen -t rsa` and follow the instructions. You'll find your keypair beneath _~/.ssh_.

Now install the public keys on the servers you want to backup, and the private key on this container.

### Dirvish

- Initialize new vault
    - `time dirvish --init --vault name_of_vault`
