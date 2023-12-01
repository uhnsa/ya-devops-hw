#!/bin/bash
code=$(curl -s -o /dev/null -w "%{http_code}" localhost/ping)
if [ $code -ne 200 ]; 
then 
        echo "restart bingo service";
        sudo systemctl restart bingo.service; 
        sleep 30;
fi
echo "OK"
exit