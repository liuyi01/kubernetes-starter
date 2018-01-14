#!/bin/bash

declare -A kvs=()

function replace_files() {
    local file=$1 
    if [ -f $file ];then
        echo "$file"
        for key in ${!kvs[@]}
        do
            value=${kvs[$key]}
            value=${value//\//\\\/}
            sed -i "s/{{$key}}/${value}/g" $file
        done
        return 0
    fi
    if [ -d $file ];then
        for f in `ls $file`
        do
            replace_files "${file}/${f}"
        done
    fi
    return 0
}

target=$1

if [ "$target" != "simple" -a "$target" != "with-ca" ];then
    echo -e "Usage:\n\t sh gen-config.sh (simple / with-ca)"
    exit 1
fi

if [ "$target" == "simple" ];then
    folder="kubernetes-simple"
else
    folder="kubernetes-with-ca"
fi

target="target"
rm -fr $target
cp -r $folder $target
cd $target

echo "====替换变量列表===="
while read line;do  
    if [ "${line:0:1}" == "#" -o "${line:0:1}" == "" ];then
        continue;
    fi
    key=${line/=*/}
    value=${line#*=}
    echo "$key=$value"
    kvs["$key"]="$value"
done < ../config.properties
echo "===================="

echo "====替换配置文件===="
for element in `ls`
do  
    dir_or_file=$element
    if [ ! -d $dir_or_file ];then
        continue 
    fi  
    replace_files $dir_or_file
done
echo "================="
echo "配置生成成功，位置: `pwd`"
