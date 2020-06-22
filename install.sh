#!/usr/bin/env bash
#安装lnmp wordpress v2ray
#v1.0 2020-06-21

# 校正vps时间
date_modify() {
  date_cn=`date -R | awk '{print $6}'`
  if [ $date_cn != "+0800" ]
      then
      echo "时间不对，正在校正时间" && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "校正完毕，vps时间已经正确"
  else
      echo "时间正确，无须校正"
  fi
}

# 安装lnmp1.7
lnmp_install(){
  screen_status=`rpm -q screen`
  if [ $? -eq 0 ];then
    echo "screen 已经安装"
  else
    yum install screen -y
  fi

  lnmp_status=`lnmp status`
  if [ $? -ne 0 ]
      then
      wget http://soft.vpser.net/lnmp/lnmp1.7.tar.gz -cO lnmp1.7.tar.gz && tar zxf lnmp1.7.tar.gz && cd lnmp1.7 && ./install.sh lnmp
  fi
}

# 申请SSL泛证书
ssl_install() {
  echo -en "\e[1;32m输入你的域名： \e[0m" && read web_name
  ping -c 1 -W1 $web_name &>/dev/null
  if [ $? -eq 0 ];then
    echo "$web_name解析成功"
  else
    echo "请检查$web_name的DNS解析是否正确"
  fi

  echo "配置泛证书DNS记录"
  export Namecom_Username="since2004" && export Namecom_Token="ac0d5bfb861163c680cacddcbbd8b75c94087df5"

  echo "检查socat命令是否安装"
  socat_status=`rpm -q socat`
  if [ $? -eq 0 ];then
    echo "socat命令已经安装"
  else
    echo "socat命令开始安装"
    yum install socat -y
  fi

  echo "开始申请证书"
  lnmp onlyssl namecom
}

# 创建lnmp虚拟主机
vhost_create() {
  lnmp vhost add
  echo "虚拟主机已经创建完成"
}

# 安装wordpress
wordpress_install() {
  if [ -f wordpress-5.4.2-zh_CN.tar.gz ];then
    echo "wordpress安装包已经下载，开始安装"
    echo -en "\e[1;32m输入网站域名[注只能输入主域名，如aaa.com，否则报错]： \e[0m"
    read web_name
    tar -zxvf wordpress-5.4.2-zh_CN.tar.gz && mv wordpress/* /home/wwwroot/www.$web_name && rm -rf wordpress
    chattr -i /home/wwwroot/www.$web_name
    chown -R www:www /home/wwwroot/$web_name
    echo "请去浏览器输入www.mrwen.me安装网站"
  else
    echo "wordpress安装包没有下载，下载wordpress安装包"
    wget https://github.com/man2018/install_lnmp_v2ray/releases/download/5.4.2/wordpress-5.4.2-zh_CN.tar.gz
    echo -en "\e[1;32m输入网站域名[注只能输入主域名，如aaa.com，否则报错]： \e[0m"
    read web_name
    tar -zxvf wordpress-5.4.2-zh_CN.tar.gz && mv wordpress/* /home/wwwroot/www.$web_name && rm -rf wordpress
    
    chattr_status=`rpm -q chown`
    if [ $? != 0 ];then
      yum install chattr -y 
    else
      echo "chown已经安装"
    fi
    
    chown_status=`rpm -q chown`
    if [ $? != 0 ];then
      yum install chown -y 
    else
      echo "chown已经安装"
    fi
    
    chattr -i /home/wwwroot/www.$web_name
    chown -R www:www /home/wwwroot/www.$web_name
    echo "请去浏览器输入www.$web_name安装网站"
  fi
}

# 更改网站配置文件
vhost_config_modify() {
echo -en "\e[1;32m输入网站域名[注只能输入主域名，如aaa.com，否则报错]： \e[0m"
read web_name

if [ -f /usr/local/nginx/conf/vhost/www.$web_name.conf ];then
    mv /usr/local/nginx/conf/vhost/www.$web_name.conf /usr/local/nginx/conf/vhost/www.$web_name.conf.bak-`date "+%F-%H:%M:%S"`
fi

echo "正在下载$web_name网站配置文件"

web_conf_status=`[ -f web.conf ]`
if [ $? != 0 ];then
  wget https://raw.githubusercontent.com/man2018/install_lnmp_v2ray/master/web.conf
fi

echo "下载成功，正在写入配置$web_name配置文件"
th=`sed 's/your-domain/'${web_name}'/g' web.conf`
cat > /usr/local/nginx/conf/vhost/www.$web_name.conf <<-EOF
$th
EOF

echo "配置文件写入成功，重启lnmp环境"
lnmp restart
echo "lnmp重启成功"
}

# 安装v2ray
v2ray_install() {
  v2ray_status=`netstat -tulnp | grep v2ray | awk '{print $7}' | awk -F "/" '{print $2}'`
  if [[ $v2ray_status != "v2ray" ]]
      then
      wget https://raw.githubusercontent.com/man2018/v2/master/go-new.sh && chmod a+x go-new.sh && ./go-new.sh
  fi
  echo "v2ray已经安装成功"
}

# 修改v2ray配置文件
v2ray_config_modify() {
echo -en "\e[1;32m输入网站域名[注只能输入主域名，如aaa.com，否则报错]： \e[0m" && read web_name

[ -f /etc/v2ray/config.json ]
if [ $? -eq 0 ];then
  mv /etc/v2ray/config.json /etc/v2ray/config.json.bak-`date "+%F-%H:%M:%S"`
fi

echo "下载v2ray配置文件"

v2ray_conf_status=`[ -f v2ray.conf ]`
if [ $? != 0 ];then
  wget https://raw.githubusercontent.com/man2018/install_lnmp_v2ray/master/v2ray.conf
fi

echo "下载成功，正在写入配置v2ray配置文件"
th=`sed 's/your-domain.com/'${web_name}'/g' v2ray.conf`
cat > /etc/v2ray/config.json <<-EOF
$th
EOF
echo "v2ray配置文件写入成功，重启服务"

systemctl restart v2ray.service
systemctl status v2ray.service
echo "v2ray配置文件已经修改，并且v2ray服务启动成功"
}

# 以下为选项
while :
do
cat <<-EOF
+-------------------------------------------------------------------------------------+
                                输入你要的选项
                                1. 校正vps时间
                                2. 安装lnmp1.7
                                3. 创建lnmp虚拟主机
                                4. 申请ssl泛证书
                                5. 安装wordpress
                                6. 修改网站配置文件
                                7. 安装v2ray
                                8. 修改v2ray配置文件
                                q. 退出
+-------------------------------------------------------------------------------------+
EOF
    echo -en "\e[1;32m输入选项: \e[0m"
    read num
    case $num in
        1)
        date_modify
        ;;
        2)
        lnmp_install
        ;;
        3)
        vhost_create
        ;;
        4)
        ssl_install
        ;;
        5)
        wordpress_install
        ;;
        6)
        vhost_config_modify
        ;;
        7)
        v2ray_install
        ;;
        8)
        v2ray_config_modify
        ;;
        "q")
        exit
        ;;
        "")
        ;;
        *)
        echo "输入错误"
        ;;
    esac
done
