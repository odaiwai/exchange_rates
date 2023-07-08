-- Replace d record with a timestamp like %Y-%m-%d to one 
-- with %Y%m%
UPDATE AUD 
    SET Timestamp = (substr(date,1,4) ||
                     substr(date,6,2) ||
                     substr(date,9,2))
        WHERE Timestamp like '%-%-%';
