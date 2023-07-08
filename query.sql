--Query to get a list of rates
Select DISTINCT HKD.Date,
        1 as HKD,
        USD.HKD as USD,
        AUD.HKD as AUD,
        EUR.HKD as EUR,
        GBP.HKD as GBP
    from HKD 
    join USD using(timestamp) 
    join aud using(timestamp) 
    join eur using(timestamp) 
    join gbp using(timestamp)
    WHERE timestamp > 20120000
    order by HKD.Date asc
