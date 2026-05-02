
salt (16 bytes)
filename_hash (32 bytes)
mac_prev (16 bytes)


## Testes de integridade (MAC chain / rename attack)

### Criar dois logs com a mesma key - check

```
python3 logappend.py -T 1 -K secret -A -E Bob f1
```

```
python3 logappend.py -T 1 -K secret -A -E Bob f2
```

em logs
```
mv f2 f1
```

```
python3 logread.py -K secret -S f1
```

**Esperado:**

```
integrity violation
```


# Testes de integridade — truncation attack - check

Cria um log válido:
```
python3 logappend.py -T 1 -K secret -A -E Bob logX
python3 logappend.py -T 2 -K secret -A -E Bob -R 1 logX
python3 logappend.py -T 3 -K secret -L -E Bob -R 1 logX
```

em logs
```
truncate --size=-16 logX
```

```
python3 logread.py -K secret -S logX
```

Esperado:
```
integrity violation
```

# Testes de integridade — bit‑flip attack

```
python3 logappend.py -T 1 -K secret -A -E Bob logY
hexedit logY   # altera 1 byte no ciphertext
python3 logread.py -K secret -S logY
```

Esperado:

```
integrity violation
```

# Testes de confidencialidade - check

Criar log:

Code

```
python3 logappend.py -T 1 -K secret -A -E Bob conf
python3 logappend.py -T 2 -K secret -A -G Jill conf
```

Agora tenta ler sem token:

Code

```
cat conf
```

**Esperado:**

- ficheiro deve parecer **ruído criptográfico**
- **não** deve ser possível inferir nomes, rooms, timestamps
    

Se conseguires ver strings → falha de confidencialidade.

cat conf


# 6. Testes de múltiplas pessoas no mesmo room

```
python3 logappend.py -T 1 -K secret -A -E A logR
python3 logappend.py -T 2 -K secret -A -E B logR
python3 logappend.py -T 3 -K secret -A -E A -R 1 logR
python3 logappend.py -T 4 -K secret -A -E B -R 1 logR
```

```
python3 logread.py -K secret -S logR
```

Esperado:

Code

```
A,B
1: A,B
```


# 9. Testes de batch — inválidos mas deve continuar

```
-T 0 -K secret -A -E Bob errors
-T 1 -K secret -A -E Bob errors
-T 2 -K secret -A -E Carl -R 1 errors
-T 3 -K secret -A -E Dan errors
-T 4 -K secret -A -E Dan -R 1 errors
-T 5 -K secret -A -E Dan -R 2 errors
```

```
python3 logappend.py -B batch_err
```

Esperado:

- imprimir **5 invalid**
- continuar até ao fim
- exit code = 0
    

# 10. Testes de batch — criação de log só no primeiro válido

Ficheiro `batch_mixed`:

Code

```
-T 0 -K secret -A -E Bob logZ
-T 1 -K secret -A -E Bob logZ
-T 2 -K secret -A -E Bob -R 1 logZ
```

Esperado:

Code

```
invalid
<log created at T=1>
<room entry at T=2>
```