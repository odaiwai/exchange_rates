--Query to get a list of rates
Select DISTINCT HKD.Date,
        1 as HKD,
        USD.HKD as USD,
        AUD.HKD as AUD,
        EUR.HKD as EUR,
        GBP.HKD as GBP
    from HKD
    join USD using(date)
    join aud using(date)
    join eur using(date)
    join gbp using(date)
    order by HKD.Date asc
