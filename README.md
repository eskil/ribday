# Ribday

```
mix deps.get
mix escript.build
./ribday -vvvv --to "1976-01-01T00:00:00Z"  --token="<token>" 2> debug > out.csv
```

To reverse output
```
head -n 1 out.csv > result.csv && tail -n +2 out.csv | tail -r >> result.csv
```
