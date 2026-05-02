python3 logappend.py -T 1 -K secret -A -E Alex jc
python3 logappend.py -T 2 -K secret -A -G Jill jc
python3 logappend.py -T 3 -K secret -A -E Alex -R 1 jc
python3 logappend.py -T 4 -K secret -A -G Jill -R 2 jc
python3 logappend.py -T 5 -K secret -L -E Alex -R 1 jc
python3 logappend.py -T 6 -K secret -A -E Alex -R 3 jc
python3 logappend.py -T 7 -K secret -A -G Alex jc
python3 logappend.py -T 8 -K secret -A -G Alex -R 10 jc
python3 logappend.py -T 9 -K secret -L -E Alex -R 3 jc
python3 logappend.py -T 10 -K secret -A -E Alex -R 1 jc



python3 logread.py -K secret -S jc

Alex
Alex, Jill
1: Alex
2: Jill
3:
10: Alex

python3 logread.py -K secret -R -E Alex jc
1,3,1

python3 logread.py -K secret -R -G Jill jc
2

python3 logread.py -K secret -R -G Alex jc
10



-T 1 -K secret -A -E Alex jc
-T 2 -K secret -A -G Jill jc
-T 3 -K secret -A -E Alex -R 1 jc
-T 4 -K secret -A -G Jill -R 2 jc
-T 5 -K secret -L -E Alex -R 1 jc
-T 6 -K secret -A -E Alex -R 3 jc
-T 7 -K secret -A -G Alex jc
-T 8 -K secret -A -G Alex -R 10 jc
-T 9 -K secret -L -E Alex -R 3 jc
-T 10 -K secret -A -E Alex -R 1 jc


````
key = (name, role)
last_event = None
last_room = None

if key in people:
    last_event = people[key]['event']
    last_room = people[key]['room']

# ARRIVAL TO GALLERY
if event_type == 'arrival' and room is None:
    # cannot arrive twice without leaving
    if last_event == 'arrival' and last_room is None:
        print("invalid 3")
        exitInvalid(typec)

# ARRIVAL TO ROOM
if event_type == 'arrival' and room is not None:
    # must have arrived to gallery before
    if last_event is None:
        print("invalid 4")
        exitInvalid(typec)
    # cannot enter a room if already in a room
    if last_room is not None:
        print("invalid 5")
        exitInvalid(typec)

# LEAVE ROOM
if event_type == 'leave' and room is not None:
    # must be in that room
    if last_room != room:
        print("invalid 6")
        exitInvalid(typec)

# LEAVE GALLERY
if event_type == 'leave' and room is None:
    # cannot leave gallery while in a room
    if last_room is not None:
        print("invalid 7")
        exitInvalid(typec)
    # cannot leave gallery without having arrived
    if last_event is None:
        print("invalid 8")
        exitInvalid(typec)

```