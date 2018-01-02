#!/bin/bash

target=$1

if [ "$target" != "simple" -a "$target" != "with-ca" ];then
    echo -e "Usage:\n\t sh gen-config.sh (simple / with-ca)"
    exit 1
fi

if [ "$target" == "simple" ];then
    folder="kubernetes-simple"
    config_file=config.properties
else
    folder = "kubernetes-with-ca"
fi

target="${folder}-target"
if [ -e $target ];then
    rm -fr $target
fi
cp -r $folder $target
cd $target

declare -A kvs=()
echo "====替换变量列表===="
while read line;do  
    if [ "${line:0:1}" == "#" -o "${line:0:1}" == "" ];then
        continue;
    fi
    eval $line
    key=${line/=*/}
    value=${line#*=}
    echo "$key=$value"
    kvs["$key"]="$value"
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
        for key in ${!kvs[@]}
        do
            value=${kvs[$key]}
            value=${value//\//\\\/}
            echo "sed -i \"\" 's/{{$key}}/${value}/g' $dir_or_file/$file"
            sed -i "" 's/{{$key}}/${value}/g' $dir_or_file/$file
        done
    done
done

