#!/bin/bash
# kerberos-setup.sh

set -x

echo "#### start to setup kerberos ####"
: ${KERB_ADMIN_USER:=admin}
: ${KERB_ADMIN_PASS:=admin}
: ${SEARCH_DOMAINS:=indata.com}

: ${DEFAULT_REALM:=INDATA.COM}
: ${REALM:=indata.com} 
: ${DEFAULT_ENCTYPES:=rc4-hmac}  
: ${DNS_LOOKUP_REALM:=false}
: ${DNS_LOOKUP_KDC:=false}
: ${TICKET_LIFETIME:=24h}
: ${RENEW_LIFETIME:=7d}
: ${FORWARDABLE:=false}
: ${CLOCKSKEW:=120}
: ${UDP_PREFERENCE_LIMIT:=1}
: ${INITIALIZE_DB_PASSWORD:=kerberos_db_password}


: ${KDC_PORTS:=88}
: ${KADMIND_PORT:=749} 
: ${MASTER_KEY_TYPE:=aes256-cts-hmac-sha1-96} 
: ${SUPPORTED_ENCTYPES:=rc4-hmac:normal des3-cbc-sha1:normal aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal}
: ${MAX_LIFE:=24h 0m 0s}
: ${MAX_RENEWABLE_LIFE:=7d 0h 0m 0s}


prepare() {
  if [ ! -d /var/kerberos/krb5kdc ];then
    /bin/cp -a /opt/kerberos /var/
    mkdir -p /var/log/kerberos
  fi
}

fix_hostname() {
  sed -i "/^hosts:/ s/ *files dns/ dns files/" /etc/nsswitch.conf
}

generate_krb5_conf() {
  : ${KDC_ADDRESS:=$(hostname -f)}

  cat>/etc/krb5.conf<<EOF
[logging]
 default = FILE:/var/log/kerberos/krb5libs.log
 kdc = FILE:/var/log/kerberos/krb5kdc.log
 admin_server = FILE:/var/log/kerberos/kadmind.log
[libdefaults]
 default_realm = ${DEFAULT_REALM}
 dns_lookup_realm = ${DNS_LOOKUP_REALM}
 dns_lookup_kdc = ${DNS_LOOKUP_KDC}
 ticket_lifetime = ${TICKET_LIFETIME}
 renew_lifetime = ${RENEW_LIFETIME}
 forwardable = ${FORWARDABLE}
 default_tgs_enctypes = ${DEFAULT_ENCTYPES}
 default_tkt_enctypes = ${DEFAULT_ENCTYPES}
 permitted_enctypes = ${DEFAULT_ENCTYPES}
 clockskew = ${CLOCKSKEW}
 udp_preference_limit = ${UDP_PREFERENCE_LIMIT}
[realms]
 ${DEFAULT_REALM} = {
  kdc = ${KDC_ADDRESS}
  admin_server = ${KDC_ADDRESS}
 }
[domain_realm]
 .${REALM} = ${DEFAULT_REALM}
 ${REALM} = ${DEFAULT_REALM}
EOF
}


generate_kdc_conf() {
  cat>/var/kerberos/krb5kdc/kdc.conf<<EOF
[kdcdefaults]
 kdc_ports = ${KDC_PORTS}
 kdc_tcp_ports = ${KDC_PORTS}
[realms]
 ${DEFAULT_REALM} = {
  #master_key_type = ${MASTER_KEY_TYPE}
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  supported_enctypes = ${SUPPORTED_ENCTYPES}
  max_life = ${MAX_LIFE}
  max_renewable_life = ${MAX_RENEWABLE_LIFE}
  dict_file = /usr/share/dict/words
  key_stash_file = /var/kerberos/krb5kdc/.k5.${DEFAULT_REALM}
  database_name = /var/kerberos/krb5kdc/principal
  default_principal_flags = +renewable, +forwardable
 }
EOF
}

create_db() {
  /usr/sbin/kdb5_util -P ${INITIALIZE_DB_PASSWORD} -r ${DEFAULT_REALM} create -s
}


generate_supervisord_conf() {
  cat > /usr/local/kerberos/supervisord.conf <<EOF
[supervisord]
pidfile = /var/run/supervisord.pid
nodaemon = true
 
[unix_http_server]
file = /var/run/supervisor.sock
chmod = 0777
 
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
 
[supervisorctl]
serverurl = unix:///var/run/supervisor.sock
 
[program:krb5kdc]
user = root
command = /usr/sbin/krb5kdc -n -P /var/run/krb5kdc.pid $KRB5KDC_ARGS
autostart=true
startsecs=3
startretries=3
autorestart=true
priority=600
 
[program:kadmind]
user = root
command = /usr/sbin/_kadmind -nofork -P /var/run/kadmind.pid $KADMIND_ARGS
autostart=true
startsecs=3
startretries=3
autorestart=true
priority=700
EOF
}


start_kerberos() {
  /usr/bin/supervisord -c /usr/local/kerberos/supervisord.conf
}

create_admin_user() {
  kadmin.local -q "addprinc -pw $KERB_ADMIN_PASS $KERB_ADMIN_USER/admin"
  echo "*/admin@${DEFAULT_REALM}   *" > /var/kerberos/krb5kdc/kadm5.acl
}

main() {
  source /etc/sysconfig/kadmin
  source /etc/sysconfig/krb5kdc

  if [ ! -f /tmp/kerberos_initialized ]; then
    prepare
    fix_hostname
    generate_krb5_conf
    generate_kdc_conf
    create_db
    create_admin_user
    generate_supervisord_conf
    start_kerberos

    touch /tmp/kerberos_initialized
  fi

  if [ ! -f /var/kerberos/krb5kdc/principal ]; then
    while true; do sleep 1000; done
  else
    start_kerberos
    tail -F /var/log/kerberos/krb5kdc.log
  fi
}

main
