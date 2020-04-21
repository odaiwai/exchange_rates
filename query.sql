--Query to get a list of rates 
Select HKD.date, 1 as HKD, USD.HKD, AUD.HKD, EUR.HKD, GBP.HKD from HKD 
	join USD using(timestamp) 
	join aud using(timestamp) 
	join eur using(timestamp) 
	join gbp using(timestamp) 
	order by timestamp;
