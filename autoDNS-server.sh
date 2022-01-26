#!/bin/bash

# 実行権限の確認
if [ "$(id -u)" -ne 0 ]; then
  printf "** 実行エラー **\nroot権限で実行してください。\n"
  return 2> /dev/null
  exit
fi

#関数の定義
function echo-zone(){
echo -e "\$TTL 3H\n\
\$ORIGIN sample.jp.\n\
@\tIN SOA dns01 root (\n \
\t\t\t\t`date +%Y%m%d`01 ;serial\n\
\t\t\t\t1D  \t ;refresh\n\
\t\t\t\t1H  \t ;retry\n\
\t\t\t\t1W  \t ;expire\n\
\t\t\t\t3H )\t ;minimum\n\
\t\tNS\tdns01.engineer.jp.\n\
\t\tMX 10\tmail.engineer.jp.\n\n\
user1\t\tA\t192.168.255.1\n\
dns01\t\tA\t192.168.255.2\n\
dns02\t\tA\t192.168.255.3\n\
web01\t\tA\t192.168.255.4\n\
web02\t\tA\t192.168.255.5\n\
db01\t\tA\t192.168.255.6\n\
db02\t\tA\t192.168.255.7\n" > /var/named/*sample.jp.zone*
}

function echo-named.conf(){
echo -e "zone \"sample.jp\" IN {\n\
\ttype master;\n\
\tfile \"engineer.jp.zone\";\n \
};" >> /etc/named.conf
}

function cp-echo(){
  if [ "$1" = "named.empty" ] ; then
  echo-zone
  cat /var/named/engineer.jp.zone
  sleep 20
  else
  cp -p "$1" "$1".org
  ls -l "$1"*
  sleep 10
  echo-named.conf
  vi "$1"
  diff "$1".org "$1"
  sleep 20
  fi
}

# ホスト名設定、タイムゾーン設定
 hostnamectl set-hostname *sample.jp*
 timedatectl set-timezone Asia/Tokyo

#yumのアップデート
 printf "yumをアップデートします。\n"
 sleep 3
 yum -y update 

#yumのインストール
 printf "bind bind-chroot bind-utils をダウンロードします。\n"
 sleep 1
 yum -y install \
  bind          \
  bind-utils    \
  bind-chroot 

#dnsの設定
 cd /etc || exit
 cp-echo named.conf

#ZONEの設定
 cd /var/named || exit
 cp-echo named.empty
 ls -l named.empty
 ls -l sample.jp.zone
 sleep 10

#設定の確認
 printf "\n /etc/named.conf の確認 \n"
 named-checkconf
 sleep 10
 printf "\n /var/named/engineer.jp.zone の確認 \n"
 named-checkzone sample.jp. sample.jp.zone
 sleep 10 

#ファイアウォールの設定
 firewall-cmd --add-service=dns --permanent
 firewall-cmd --reload
 printf "\n ファイアウォールの確認 \n"
 firewall-cmd --list-services --permanent
 sleep 10

#BINDの起動と設定
 systemctl start named-chroot
 systemctl status named-chroot
 systemctl enable named-chroot
 printf "\n 自動起動の確認 \n"
 systemctl is-enabled named-chroot
 sleep 10

#ネットワーク設定
 nmcli c mod enp0s3 connection.autoconnect yes
 nmcli c mod enp0s3 ipv4.method manual ipv4.addresses 192.168.1.***/24 ipv4.gateway 192.168.1.***
 nmcli c mod enp0s3 ipv4.dns 192.168.1.1***
 nmcli c mod enp0s3 +ipv4.dns 192.168.1.***
 nmcli c mod enp0s3 +ipv4.dns 8.8.8.8,8.8.4.4
 #nmcli c down enp0s3 && nmcli c up enp0s3
 systemctl restart named-chroot

#名前解決とリゾルバの確認
 sleep 10
 printf "\n 名前解決の確認 \n"
 dig *sample.jp axfr*
 printf "\n リゾルバの確認 \n"
 cat /etc/resolv.conf