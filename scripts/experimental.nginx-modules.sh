
alias nginx_version="nginx -V 2>&1 | sed 's/--/\n--/g'"

function nginx_notes() {
    echo "
    # remove server headers with module ngx_security_headers, ngx_headers_more_module - more_clear_headers
    https://github.com/GetPageSpeed/ngx_security_headers

    # packages for yum install of nginx with modules prebuilt
    https://www.getpagespeed.com/nginx-extras

    # this page has notes of dynamic vs static build of nginx module
    https://github.com/leev/ngx_http_geoip2_module

    # READING around openssl 1.1.1 for TLS1.3 on centos7 and issues
    https://packages.exove.com/nginx-http2.html
    https://www.dark-hamster.com/operating-system/how-to-install-nginx-in-linux-centos-7/
    https://blog.cloudflare.com/hpack-the-silent-killer-feature-of-http-2/
    https://github.com/ajdruff/nginx-naxsi-rpm/blob/master/how-to-build-your-own-nginx-rpm.md


    # Nginx headers more modules
    https://serverdiary.com/linux/remove-nginx-server-header-with-nginx-headers-more-filter-module/


    # Nginx virtual host traffic status module
    https://serverdiary.com/web-server/nginx-virtual-host-traffic-status-module-to-monitor-nginx/


    # Building NGINX
    https://www.photographerstechsupport.com/tutorials/hosting-wordpress-on-aws-tutorial-part-2-setting-up-aws-for-wordpress-with-rds-nginx-hhvm-php-ssmtp/#nginx-source

    https://www.oodlestechnologies.com/blogs/setup-headers-more-nginx-module-using-dynamic-compilation/

    https://serverdiary.com/linux/how-to-install-and-configure-nginx-modsecurity-on-centos-7/
    https://serverdiary.com/web-server/nginx-virtual-host-traffic-status-module-to-monitor-nginx/
    https://serverdiary.com/linux/remove-nginx-server-header-with-nginx-headers-more-filter-module/
    https://www.nginx.com/resources/wiki/modules/

    https://www.theshell.guru/error-the-http-image-filter-module-requires-the-gd-library-nginx-centos-7-3/

    https://www.nginx.com/blog/compiling-dynamic-modules-nginx-plus/
    https://www.nginx.com/resources/wiki/modules/

    use alias 'nginx_version' to see how nginx was built

    use function 'build_nginx_modules' to build some nginx modules against current version (as best as can be)
"

}


function build_nginx_modules() {

    # create array of the configuration of the existing installed nginx - we match this (standard default yum install) when creating new modules
    nginx_conf_args=($(nginx -V 2>&1 | sed 's/configure arguments:/\nconf_args:/g' | grep 'conf_args' | cut -d: -f2 | sed 's/--with-ipv6/ /'))
    nginx_version=$(nginx -v 2>&1 | cut -d/ -f2)

    echo "building for nginx $nginx_version"

    pushd /usr/src && \
    [ -e ./nginx-${nginx_version}.tar.gz ] && true || wget http://nginx.org/download/nginx-${nginx_version}.tar.gz && \
    tar zxvf nginx-${nginx_version}.tar.gz && \
    cd nginx-${nginx_version}

    # install dependencies
    yum -y install openssl11-libs openssl11-static gcc-c++ flex bison yajl yajl-devel curl-devel curl \
        GeoIP-devel doxygen zlib-devel pcre-devel lmdb lmdb-devel libxml2 libxml2-devel ssdeep ssdeep-devel \
        lua lua-devel gd gd-devel perl-ExtUtils-Embed gperftools-devel libxslt-devel

    # Nginx headers more modules
    #   https://serverdiary.com/linux/remove-nginx-server-header-with-nginx-headers-more-filter-module/
    pushd /usr/src && rm -rf headers-more-nginx-module || true && git clone https://github.com/openresty/headers-more-nginx-module.git && popd

    # Nginx virtual host traffic status module
    #   https://serverdiary.com/web-server/nginx-virtual-host-traffic-status-module-to-monitor-nginx/
    pushd /usr/src && rm -rf nginx-module-vts || true && git clone https://github.com/vozlt/nginx-module-vts.git && popd

    # configure

    echo "./configure \\
        ${nginx_conf_args[@]} \\
        --with-compat \\
        --add-dynamic-module=/usr/src/headers-more-nginx-module \\
        --add-dynamic-module=/usr/src/nginx-module-vts \\
        " > ./configureit && \


    # lets try static linking openssl11
    --with-cc-opt=\"-static -static-libgcc\" --with-ld-opt=\"-static\" \ # try static linking
    # --with-openssl=/usr/lib64/libssl.so.1.1.1k \ # yum -y install openssl11-libs openssl11-static openssl11-devel
    echo "./configure \\
        ${nginx_conf_args[@]} \\
        --with-compat \\
        --add-dynamic-module=/usr/src/headers-more-nginx-module \\
        --add-dynamic-module=/usr/src/nginx-module-vts \\
        --with-openssl=/usr/include/openssl11 \\
        " > ./configureit_withssl && \


    #bash configureit_withssl
    bash configureit

    # build it
    make modules

    # make install
    # lets manually install the modules
    /bin/cp -f objs/ngx_http_headers_more_filter_module.so /usr/lib64/nginx/modules/
    /bin/cp -f objs/ngx_http_vhost_traffic_status_module.so /usr/lib64/nginx/modules/

    echo 'load_module "/usr/lib64/nginx/modules/ngx_http_headers_more_filter_module.so";' >> /etc/nginx/nginx.conf
    echo 'load_module "/usr/lib64/nginx/modules/ngx_http_vhost_traffic_status_module.so";' >> /etc/nginx/nginx.conf

    sudo systemctl restart nginx
    # for older nginx -V output - remove deprecated options - --with-ipv6

}

