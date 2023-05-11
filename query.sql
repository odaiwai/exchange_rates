--Query to get a list of rates
Select  (substr(timestamp,1,4) || '-' ||
         substr(timestamp,5,2) || '-' ||
         substr(timestamp,7,2)) as Date,
        1 as HKD, USD.HKD as USD, AUD.HKD as AUD, EUR.HKD as EUR, GBP.HKD as GBP from HKD 
    join USD using(timestamp) 
    join aud using(timestamp) 
    join eur using(timestamp) 
    join gbp using(timestamp)
    WHERE timestamp > 20120000
    order by timestamp;
