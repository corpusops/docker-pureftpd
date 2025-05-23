
DISCLAIMER - ABANDONED/UNMAINTAINED CODE / DO NOT USE
=======================================================
While this repository has been inactive for some time, this formal notice, issued on **December 10, 2024**, serves as the official declaration to clarify the situation. Consequently, this repository and all associated resources (including related projects, code, documentation, and distributed packages such as Docker images, PyPI packages, etc.) are now explicitly declared **unmaintained** and **abandoned**.

I would like to remind everyone that this project’s free license has always been based on the principle that the software is provided "AS-IS", without any warranty or expectation of liability or maintenance from the maintainer.
As such, it is used solely at the user's own risk, with no warranty or liability from the maintainer, including but not limited to any damages arising from its use.

Due to the enactment of the Cyber Resilience Act (EU Regulation 2024/2847), which significantly alters the regulatory framework, including penalties of up to €15M, combined with its demands for **unpaid** and **indefinite** liability, it has become untenable for me to continue maintaining all my Open Source Projects as a natural person.
The new regulations impose personal liability risks and create an unacceptable burden, regardless of my personal situation now or in the future, particularly when the work is done voluntarily and without compensation.

**No further technical support, updates (including security patches), or maintenance, of any kind, will be provided.**

These resources may remain online, but solely for public archiving, documentation, and educational purposes.

Users are strongly advised not to use these resources in any active or production-related projects, and to seek alternative solutions that comply with the new legal requirements (EU CRA).

**Using these resources outside of these contexts is strictly prohibited and is done at your own risk.**

This project has been transfered to Makina Corpus <freesoftware@makina-corpus.com> ( https://makina-corpus.com ). This project and its associated resources, including published resources related to this project (e.g., from PyPI, Docker Hub, GitHub, etc.), may be removed starting **March 15, 2025**, especially if the CRA’s risks remain disproportionate.

Docker Pure-ftpd Server
============================
 
https://hub.docker.com/r/corpusops/pureftpd/

[![.github/workflows/cicd.yml](https://github.com/corpusops/docker-pureftpd/workflows/.github/workflows/cicd.yml/badge.svg?branch=master)](https://github.com/corpusops/docker-pureftpd/actions?query=workflow%3A.github%2Fworkflows%2Fcicd.yml+branch%3Amaster)

----------------------------------------

#### Check out our [basic example workflow](https://github.com/corpusops/setups.docker-pureftpd/wiki/Basic-example-walk-through) &
      our [slightly more advanced workflow with tls & an auto created user](https://github.com/corpusops/setups.docker-pureftpd/wiki/Advanced-example-walk-through-with-TLS-&-automatic-user-account).

----------------------------------------

Tags available for different versions
--------------------------------------

Pull down one of the latest version with docker:
```bash
docker pull corpusops/pureftpd:latest
docker pull corpusops/pureftpd:postgresql
docker pull corpusops/pureftpd:ldap
docker pull corpusops/pureftpd:mysql
docker pull corpusops/pureftpd:hardened
docker pull corpusops/pureftpd:hardened-postgresql
docker pull corpusops/pureftpd:hardened-ldap
docker pull corpusops/pureftpd:hardened-mysql
```

----------------------------------------

**If you want to make changes, my advice is to either change the run command when running it or extend this image to make any changes rather than forking the project.**
This is because rebuilding the entire docker image via a fork can be *very* slow as it rebuilds the entire pure-ftpd package from source.

To change the command run on start you could use the `command:` option if using `docker-compose`, or with [`docker run`](https://docs.docker.com/engine/reference/run/) directly you could use:

```
docker run --rm -d --name ftpd_server -p 21:21 -p 30000-30009:30000-30009 corpusops/pureftpd:hardened bash /init.sh -c 30 -C 10 -l puredb:/etc/pure-ftpd/pureftpd.pdb -E -j -R -P localhost -p 30000:30059
```

To extend it you can create a new project with a `DOCKERFILE` like so:

```
FROM corpusops/pureftpd
# e.g. you could change the defult command run:
CMD /init.sh -c 30 -C 10 -l puredb:/etc/pure-ftpd/pureftpd.pdb -E -j -R -P $PUBLICHOST -p 30000:30059
```

*Then you can build your own image, `docker build --rm -t my-pure-ftp .`, where my-pure-ftp is the name you want to build as*

----------------------------------------

Starting it
------------------------------

`docker run -d --name ftpd_server -p 21:21 -p 30000-30009:30000-30009 -e "PUBLICHOST=localhost" corpusops/pureftpd:hardened`

*Or for your own image, replace corpusops/pureftpd with the name you built it with, e.g. my-pure-ftp*

You can also pass ADDED_FLAGS as an env variable to add additional options such as --tls to the pure-ftpd command.
e.g. ` -e "ADDED_FLAGS=--tls=2" `


Operating it
------------------------------

`docker exec -it ftpd_server /bin/bash`

Setting runtime FTP user
------------------------------

To create a user on the ftp container, use the following environment variables: `FTP_USER_NAME`, `FTP_USER_PASS` and `FTP_USER_HOME`.

`FTP_USER_HOME` is the root directory of the new user.

Example usage:

`docker run -e FTP_USER_NAME=bob -e FTP_USER_PASS=12345 -e FTP_USER_HOME=/home/bob corpusops/pureftpd`

If you wish to set the `UID` & `GID` of the FTP user, use the `FTP_USER_UID` & `FTP_USER_GID` environment variables.

Using different passive ports
------------------------------

To use passive ports in a different range (*eg*: `10000-10009`), use the following setup:

`docker run -e FTP_PASSIVE_PORTS=10000:10009 --expose=10000-10009 -p 21:21 -p 10000-10009:10000-10009`

You may need the `--expose=` option, because default passive ports exposed are `30000` to `30009`.

Example usage once inside
------------------------------

Create an ftp user: `e.g. bob with chroot access only to /home/ftpusers/bob`
```bash
pure-pw useradd bob -f /etc/pure-ftpd/passwd/pureftpd.passwd -m -u ftpuser -d /home/ftpusers/bob
```
*No restart should be needed.*

*If you have any trouble with volume permissions due to the **uid** or **gid** of the created user you can change the **-u** flag for the uid you would like to use and/or specify **-g** with the group id as well.

More info on usage here: https://download.pureftpd.org/pure-ftpd/doc/README.Virtual-Users


Test your connection
-------------------------
From the host machine:
```bash
ftp -p localhost 21
```

-------------------------

Docker compose
-------------------------
Docker compose can help you simplify the orchestration of your containers.
We have a simple   [example of the docker compose](https://github.com/corpusops/setups.docker-pureftpd/blob/master/docker-compose.yml).
& here's a [more detailed example using wordpress](https://github.com/corpusops/setups.docker-pureftpd/blob/master/docker-compose-wp.yml) with ftp using this image.

-------------------------

Max clients
-------------------------
By default we set 5 max clients at once, but you can increase this by using the following environment variable: `FTP_MAX_CLIENTS`, e.g. to `FTP_MAX_CLIENTS=50` and then also increasing the number of public ports opened from `FTP_PASSIVE_PORTS=30000:30009` `FTP_PASSIVE_PORTS=30000:30099`.
You'll also want to open those ports when running docker run.
In addition you can specify the maximum connections per ip by setting the environment variable `FTP_MAX_CONNECTIONS`. By default the value is 5.

All Pure-ftpd flags available:
--------------------------------------
https://linux.die.net/man/8/pure-ftpd

Logs
-------------------------
To get verbose logs add the following to your `docker run` command:
```
-e "ADDED_FLAGS=-d -d"
```

Then if you exec into the container you could watch over the log with `tail -f /var/log/messages`

Want a transfer log file? add the following to your `docker run` command:
```bash
-e "ADDED_FLAGS=-O w3c:/var/log/pure-ftpd/transfer.log"
```

----------------------------------------

Our default pure-ftpd options explained
----------------------------------------

```
/usr/sbin/pure-ftpd # path to pure-ftpd executable
-c 5 # --maxclientsnumber (no more than 5 people at once)
-C 5 # --maxclientsperip (no more than 5 requests from the same ip)
-l puredb:/etc/pure-ftpd/pureftpd.pdb # --login (login file for virtual users)
-E # --noanonymous (only real users)
-j # --createhomedir (auto create home directory if it doesnt already exist)
-R # --nochmod (prevent usage of the CHMOD command)
-P $PUBLICHOST # IP/Host setting for PASV support, passed in your the PUBLICHOST env var
-p 30000:30009 # PASV port range (10 ports for 5 max clients)
-tls 1 # Enables optional TLS support
```

For more information please see `man pure-ftpd`, or visit: https://www.pureftpd.org/

Why so many ports opened ?
---------------------------
This is for PASV support.

----------------------------------------

Docker Volumes
--------------
There are a few spots onto which you can mount a docker volume to configure the
server and persist uploaded data. It's recommended to use them in production.

  - `/etc/ssl/private/` A directory containing a single `pure-ftpd.pem` file
    with the server's SSL certificates for TLS support. Optional TLS is
    automatically enabled when the container finds this file on startup.
  - `/etc/pure-ftpd/passwd` A directory containing the single `pureftpd.passwd`
    file which contains the user database (i.e., all virtual users, their
    passwords and their home directories). This is read on startup of the
    container and updated by the
       `pure-pw useradd -f /etc/pure-ftpd/passwd/pureftpd.passwd ...` command.
  - `/home/ftpusers/` The ftp's data volume (by convention).

Keep user database in a volume
------------------------------
You may want to keep your user database through the successive image builds. It is possible with Docker volumes.

Create a named volume:
```
docker volume create --name my-db-volume
```

Specify it when running the container:
```
docker run -d --name ftpd_server -p 21:21 -p 30000-30009:30000-30009 -e "PUBLICHOST=localhost" -v my-db-volume:/etc/pure-ftpd/passwd corpusops/pureftpd:hardened
```

When an user is added, you need to use the password file which is in the volume:
```
pure-pw useradd bob -f /etc/pure-ftpd/passwd/pureftpd.passwd -m -u ftpuser -d /home/ftpusers/bob
```

(Thanks to the -m option, you don't need to call *pure-pw mkdb* with this syntax).


Changing a password
---------------------
e.g. to change the password for user "bob":
```
pure-pw passwd bob -f /etc/pure-ftpd/passwd/pureftpd.passwd -m
```

TLS
----
If you want to enable tls (for ftps connections), you need to have a valid
certificate. You can get one from one of the certificate authorities that you'll
find when googling this topic. The certificate (containing private key and
certificate) needs to be at:

```
/etc/ssl/private/pure-ftpd.pem
```

Use docker volumes to get the certificate there at runtime. The container will
automatically enable optional TLS when it detect the file at this location.

You can also self-sign a certificate, which is certainly the easiest way to
start out. Self signed certificates come with certain drawbacks, but it might
be better to have a self signed one than none at all.

Here's how to create a self-signed certificate from within the container:

```bash
mkdir -p /etc/ssl/private
openssl dhparam -out /etc/ssl/private/pure-ftpd-dhparams.pem 2048
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -keyout \
    /etc/ssl/private/pure-ftpd.pem \
    -out /etc/ssl/private/pure-ftpd.pem
chmod 600 /etc/ssl/private/*.pem
```

Automatic TLS certificate generation
---------------------------------------
If `ADDED_FLAGS` contains `--tls` and file `/etc/ssl/private/pure-ftpd.pem` does not exists
it is possible to generate self-signed certificate if `TLS_CN`, `TLS_ORG` and `TLS_C` are set.

Keep in mind that if no volume is set for `/etc/ssl/private/` directory generated
certificates won't be persisted and new ones will be generated on each start.

You can also pass `-e "TLS_USE_DSAPRAM=true"` for faster generated certificates
though this option is not recommended for production.

Credits
------------------------------
- Largelly inspired from [stilliard/docker-pure-ftpd](https://github.com/stilliard/docker-pure-ftpd).
- We needed more:
	- stability and control
	- More versatile entrypoint
	- All flavors of pureftpd (ldap, mysql, postgresql, vanilla), matrixed with the `hardened` mode
	- All docker friendly binaries bundled that we use generally (mainly: frep)

