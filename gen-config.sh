#!/bin/bash

target=$1

if [ "$target" != "simple" -a "$target" != "with-ca" ];then
    echo "Usage:\n\t sh gen-config.sh (simple / with-ca)"
    exit 1
fi

if [ "$target" == "simple" ];then
    folder="kubernetes-simple"
    config_file=config.properties
else
    folder = "kubernetes-with-ca"
fi

cd $folder

keys=()
idx=0
echo "====替换变量列表===="
while read line;do  
    if [ "${line:0:1}" == "#" -o "${line:0:1}" == "" ];then
        continue;
    fi
    eval $line
    key=${line/=*/}
    value=${line#*=}
    keys[$idx]=$key
    ((idx=$idx+1))
    echo "$key=$value"
done < $config_file
echo "===================="

echo "====替换配置文件===="
for element in `ls`
do  
    dir_or_file=$element
    if [ ! -d $dir_or_file ];then
        continue 
    fi  
    for file in `ls $dir_or_file`
    do
        echo $file
        for key in ${keys[@]}
        do
            eval echo "\$$key"
            echo "sed -i 's/{{$key}}/$value/g' $dir_or_file/$file"
            #sed -i 's/{{$key}}/$value/g' $dir_or_file/$file
        done
    done
done

