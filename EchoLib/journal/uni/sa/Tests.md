
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
