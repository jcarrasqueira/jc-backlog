
# No errors tests
## Logappend
### alex employee joins gallery
```
python3 logappend.py -T 1 -K secret -A -E Alex jc
```

### jill guest joins gallery
```
python3 logappend.py -T 2 -K secret -A -G Jill jc
```

### alex employee goes to room 1
```
python3 logappend.py -T 3 -K secret -A -E Alex -R 1 jc
```

### jill guest goes to room 2
```
python3 logappend.py -T 4 -K secret -A -G Jill -R 2 jc
```

### alex employee leaves room 1
```
python3 logappend.py -T 5 -K secret -L -E Alex -R 1 jc
```

### alex employee goes to room 3
```
python3 logappend.py -T 6 -K secret -A -E Alex -R 3 jc
```


### alex guest joins gallery
```
python3 logappend.py -T 7 -K secret -A -G Alex jc
```

### alex guest goes to room 10
```
python3 logappend.py -T 8 -K secret -A -G Alex -R 10 jc
```

### alex employee leaves room 3
```
python3 logappend.py -T 9 -K secret -L -E Alex -R 3 jc
```

### alex employee goes to room 1
```
python3 logappend.py -T 10 -K secret -A -E Alex -R 1 jc
```

## Logread
  
```
python3 logread.py -K secret -S jc
```

expected:
```
Alex
Alex, Jill
1: Alex
2: Jill
3:
10: Alex
```


```
python3 logread.py -K secret -R -E Alex jc
```

```
1,3,1
```


```
python3 logread.py -K secret -R -G Jill jc
```
expected:
```
2
```


```  
python3 logread.py -K secret -R -G Alex jc
```
expected:
```
10
```

# Errors that must occur
## Logappend
### Arrival to gallery twice without leaving
```
python3 logappend.py -T 1 -K secret -A -E Bob errors
```
 
```
python3 logappend.py -T 2 -K secret -A -E Bob errors
```
invalid


### Arrival to room without entering gallery first
```
python3 logappend.py -T 3 -K secret -A -E Carl -R 1 errors
```
invalid


### Arrival to room while already in a room (must be invalid)
```
python3 logappend.py -T 4 -K secret -A -E Dan errors
```

```
python3 logappend.py -T 5 -K secret -A -E Dan -R 1 errors
```

```
python3 logappend.py -T 6 -K secret -A -E Dan -R 2 errors
```
invalid


### Leaving room without being in room
```
python3 logappend.py -T 7 -K secret -A -E Eva errors
```

```
python3 logappend.py -T 8 -K secret -L -E Eva -R 1 errors
``` 
invalid

### Leave gallery while still in a room
```
python3 logappend.py -T 9 -K secret -A -E Frank errors
```

```
python3 logappend.py -T 10 -K secret -A -E Frank -R 1 errors
```

```
python3 logappend.py -T 11 -K secret -L -E Frank errors
``` 
invalid
### Leave gallery without ever arriving
```
python3 logappend.py -T 12 -K secret -L -E George errors
```

### Timestamp going backwards 
```
python3 logappend.py -T 13 -K secret -A -E Henry errors
```

```
python3 logappend.py -T 12 -K secret -A -E Henry -R 1 errors
```

### Wrong token
```
python3 logappend.py -T 14 -K wrongtoken -A -E Ian errors
```


Batch mode: invalid lines must NOT stop the batch
-K secret -T 0 -A -E John jc
-K secret -T 1 -A -R 0 -E John jc
-K secret -T 2 -A -G James jc
-K secret -T 3 -A -R 0 -G James jc

expected
invalid
invalid


valid batch
-K secret -T 1 -A -E John jc
-K secret -T 2 -A -R 0 -E John jc
-K secret -T 3 -A -G James jc
-K secret -T 4 -A -R 0 -G James jc

