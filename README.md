# Ribday

```
mix deps.get
mix escript.build
./ribday --debug -vvvv --to "0000-01-01T00:00:00Z"  --token="<token>" 2> debug > out.csv
```

To get the token, login to groupme in a browser and look at the network traffic.

To reverse output
```
head -n 1 out.csv > result.csv && tail -n +2 out.csv | tail -r >> result.csv
```
