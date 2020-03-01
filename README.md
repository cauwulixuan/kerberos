# kerberos
an image of kerberos

# how to run it
```
# build
docker build -t kerberos:v1.0 .

# or just pull image
docker pull registry.cn-hangzhou.aliyuncs.com/inspur_containers/kerberos:v1.0
docker tag [imageID] kerberos:v1.0

# run
mkdir -p /etc/kerberos/
touch /etc/kerberos/krb5.conf
docker run -d --hostname kerberos.com \
              --name kerberos-1 \
              -e DEFAULT_REALM=KERBEROS.COM \
              -e REALM=kerberos.com \
              -e INITIALIZE_DB_PASSWORD=kerberos_db_password \
              -v /etc/kerberos/krb5.conf:/etc/krb5.conf \
              -v /dev/urandom:/dev/random kerberos:v1.0
```
