FROM centos:7
 
RUN yum install -y epel-release && \
    yum install -y krb5-server krb5-libs krb5-auth-dialog supervisor krb5-server-ldap krb5-workstation krb5-auth-dialog && \
    rm -rf /var/cache/yum/*
 
RUN mkdir -p /usr/local/kerberos && \
    mv /var/kerberos /opt/kerberos
 
COPY kerberos-setup.sh /usr/local/kerberos/kerberos-setup.sh
 
EXPOSE 88 749 464

CMD ["/bin/bash", "/usr/local/kerberos/kerberos-setup.sh"]
