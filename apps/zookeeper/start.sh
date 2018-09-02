docker rm -f imooc-zookeeper
docker run --net imooc-network --name imooc-zookeeper -p 2181:2181 -d zookeeper:3.5
