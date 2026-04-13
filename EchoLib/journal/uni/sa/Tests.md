
```
python3 logappend.py -T 1 -K secret -A -E Alex log1
```

```
python3 logappend.py -T 2 -K secret -A -G Jill log1
```

```
python3 logappend.py -T 3 -K secret -A -E Alex -R 1 log1
```

```
python3 logappend.py -T 4 -K secret -A -G Jill -R 2 log1
```

```
python3 logappend.py -T 5 -K secret -L -E Alex -R 1 log1
```

```
python3 logappend.py -T 6 -K secret -A -E Alex -R 3 log1
```

```
python3 logappend.py -T 7 -K secret -A -G Alex log1
```

```
python3 logappend.py -T 8 -K secret -A -G Alex -R 10 log1
```

```
python3 logappend.py -T 9 -K secret -L -E Alex -R 3 log1
```

```
python3 logappend.py -T 10 -K secret -A -E Alex -R 1 log1
```



```
python3 logread.py -K secret -S log1
```
should return:
```
Alex
Alex, Jill
1: Alex
2: Jill
3: 
10: Alex
```


```
python3 logread.py -K secret -R -E Alex log1
```
should return:
1, 3, 1

```
python3 logread.py -K secret -R -G Jill log1
```
should return 2

```
python3 logread.py -K secret -R -G Alex log1
```
should return 10


### make file

```
make logappend ARGS="-T 1 -K secret -A -E Alex log1"
```

```
make logappend ARGS="-T 2 -K secret -A -G Jill log1"
```

```
make logappend ARGS="-T 3 -K secret -A -E Alex -R 1 log1"
```

```
make logappend ARGS="-T 4 -K secret -A -G Jill -R 2 log1"
```

```
make logappend ARGS="-T 5 -K secret -L -E Alex -R 1 log1"
```

```
make logappend ARGS="-T 6 -K secret -A -E Alex -R 3 log1"
```

```
make logappend ARGS="-T 7 -K secret -A -G Alex log1"
```

```
make logappend ARGS="-T 8 -K secret -A -G Alex -R 10 log1"
```

```
make logappend ARGS="-T 9 -K secret -L -E Alex -R 3 log1"
```

```
make logappend ARGS="-T 10 -K secret -A -E Alex -R 1 log1"
```

```
cat << 'EOF' | bash
make logappend ARGS="-T 1 -K secret -A -E Alex log1"
make logappend ARGS="-T 2 -K secret -A -G Jill log1"
make logappend ARGS="-T 3 -K secret -A -E Alex -R 1 log1"
make logappend ARGS="-T 4 -K secret -A -G Jill -R 2 log1"
make logappend ARGS="-T 5 -K secret -L -E Alex -R 1 log1"
make logappend ARGS="-T 6 -K secret -A -E Alex -R 3 log1"
make logappend ARGS="-T 7 -K secret -A -G Alex log1"
make logappend ARGS="-T 8 -K secret -A -G Alex -R 10 log1"
make logappend ARGS="-T 9 -K secret -L -E Alex -R 3 log1"
make logappend ARGS="-T 10 -K secret -A -E Alex -R 1 log1"
make read ARGS="-K secret -S log1"
EOF
```


 Get the full gallery state
```
make logread ARGS="-K secret -S log1"
```

```
# Check Alex's room history (Expected: 1, 3, 1)
make logread ARGS="-K secret -R -E Alex log1"
```

Check Jill's room history (Expected: 2)
```
make logread ARGS="-K secret -R -G Jill log1"
```

Check Alex the Guest's room history (Expected: 10)
```
make logread ARGS="-K secret -R -G Alex log1"
```