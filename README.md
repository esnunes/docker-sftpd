# esnunes/sftpd - Docker SFTP server

This Docker image is a simplified version of 
[atmoz/sftp](https://github.com/atmoz/sftp) based on 
[Alpine Linux](https://www.alpinelinux.org/).

Although it is a simplified version you can rely on most of the documentation of
atmoz/sftp.

## Usage

The users are created during the first start of the container. In case you want
to add more users you will have to remove current container and create it again.

During start server ssh keys are generated and copied to volume `/keys` in case
you don't mount a volume a new set of keys will be generated invalidating the
`known_hosts` reference.

```bash
# load users from /etc/sftp-users
docker run --ti -d -v /data/sftp-home:/home -v /data/sftp-keys:/keys \
  -v /path/to/sftp-users.conf:/etc/sftp-users.conf -p 22:22 esnunes/sftpd
```

```bash
# load user from arguments
docker run --ti -d -v /data/sftp-home:/home -p 22:22 esnunes/sftpd
myuser:mypass:1001 otheruser:otherpass:1002
```

## sftp-users.conf format

One user per line using the following pattern: `username:password:uid[:gid]`.

