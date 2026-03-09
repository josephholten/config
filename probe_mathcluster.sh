for i in 01 02 06 07 08 09 10 11 12 13 21 22; do
  echo pde$i
  ssh pde$i /bin/sh -c "lscpu | grep -E 'Model name|Core|Socket'; free -h | awk '/Mem:/{print \"Mem\t\t\" \$2}'" 2>/dev/null
done
