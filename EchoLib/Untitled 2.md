
python3 logappend.py -T 1 -K secret -A -E Alex jc

-T 2 -K secret -A -G Jill jc
-T 3 -K secret -A -E Alex -R 1 jc
-T 4 -K secret -A -G Jill -R 2 jc
-T 5 -K secret -L -E Alex -R 1 jc
-T 6 -K secret -A -E Alex -R 3 jc
-T 7 -K secret -A -G Alex jc
-T 8 -K secret -A -G Alex -R 10 jc
-T 9 -K secret -L -E Alex -R 3 jc
-T 10 -K secret -A -E Alex -R 1 jc

python3 logappend.py -T 1 -K secret -A -E Bob errors
-T 2 -K secret -A -E Bob errors
-T 3 -K secret -A -E Carl -R 1 errors
-T 4 -K secret -A -E Dan errors
-T 5 -K secret -A -E Dan -R 1 errors
-T 6 -K secret -A -E Dan -R 2 errors
-T 7 -K secret -A -E Eva errors
-T 8 -K secret -L -E Eva -R 1 errors
-T 9 -K secret -A -E Frank errors
-T 10 -K secret -A -E Frank -R 1 errors
-T 11 -K secret -L -E Frank errors

expected: 5 invalids
