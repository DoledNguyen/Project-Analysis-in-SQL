-- Kiểm tra dữ liệu
SELECT * FROM dbo.sales_data_sample
where productline = 'Classic Cars'
-- Kiểm tra các giá trị duy nhất
SELECT DISTINCT status FROM dbo.sales_data_sample
SELECT DISTINCT year_id FROM dbo.sales_data_sample -- Dữ liệu chỉ có 3 năm 2003,2004,2005
SELECT DISTINCT PRODUCTLINE FROM dbo.sales_data_sample
SELECT DISTINCT country FROM dbo.sales_data_sample
SELECT DISTINCT territory FROM dbo.sales_data_sample
SELECT DISTINCT dealsize FROM dbo.sales_data_sample

----ANALYSIS
-- Doanh số bán hàng theo dòng sản phẩm
SELECT 
productline
,sum(sales) Revenue
FROM dbo.sales_data_sample
GROUP BY productline
ORDER BY 2 desc
-- Doanh số bán hàng theo năm
SELECT 
year_id
,sum(sales) Revenue
FROM dbo.sales_data_sample
GROUP BY year_id
ORDER BY 2 desc
-- Doanh số bán hàng theo quy mô giao dịch
SELECT 
dealsize
,sum(sales) Revenue
FROM dbo.sales_data_sample
GROUP BY dealsize
ORDER BY 2 desc

/*--> Từ số liệu phân tích ta thấy dòng sản phẩm Classic Cars có doanh só bán hàng cao nhất, doanh số của quy mô giao dịch
trung bình cao hơn nhiều lần so với các quy mô giao dịch khác.
 Doanh số bán hàng năm 2004 cao nhất trong 3 năm 2003, 2004 và 2005. Có dấu hiệu bất thường ở năm 2005, ta thấy doanh số giảm sút rõ rệt.
Kiểm tra lại số tháng hoạt động trong năm 2005 */
SELECT DISTINCT MONTH_ID
FROM dbo.sales_data_sample
WHERE year_id = 2005 --2003,2004,2005

/* Trong năm 2005, họ chỉ hoạt động trong 5 tháng, còn năm 2003 và 2004 họ hoạt động cả năm. 
Đây là lý do năm 2005 doanh số bán hàng của họ thấp. Có lẽ nếu họ hoạt động cả năm thì họ có thể đã bán được nhiều hơn */

-- Tháng bán hàng tốt nhất trong một năm cụ thể là tháng nào? Số tiền kiếm được trong tháng đó là bao nhiêu?
SELECT 
month_id
,sum(sales) Revenue
,count(ordernumber) Frequency 
FROM dbo.sales_data_sample
WHERE year_id = 2003 --chi xét 2 năm 2003,2004. vÌ 2005 khÔng đủ giữ liệu để phản ánh
GROUP BY month_id
ORDER BY 2 desc
--> Tháng 11 là tháng bán hàng tốt nhất của cty 
/* ==> Sản phẩm tốt nhất là Classic Cars và tháng tốt nhất là tháng 11. Theo như dự đoán tháng 11 bán nhiều sản phẩm Classic Cars hơn các
sản phẩm khác */

-- Các sản phẩm bán ra trong tháng 11 
SELECT 
MONTH_ID, PRODUCTLINE
,sum(sales) Revenue
,count(ORDERNUMBER) Frequency
FROM dbo.sales_data_sample
WHERE YEAR_ID = 2004 and MONTH_ID = 11 
GROUP BY  MONTH_ID, PRODUCTLINE
ORDER BY 3 desc
--> Classic Cars có số lượng bán nhiều nhất trong tháng 11

-- Nước có doanh số bán hàng cao nhất 
SELECT country
,sum(sales) Revenue
,count(ordernumber) Frequency
FROM dbo.sales_data_sample
GROUP BY country
ORDER BY 2 desc
--> USA có doanh số cao vượt trội so với các nước khác

-- Thành phố có doanh số cao nhất
 SELECT city
,sum(sales) Revenue
,count(ordernumber) Frequency
FROM dbo.sales_data_sample
WHERE country = 'USA'
GROUP BY city
ORDER BY 2 desc 
--> San rafael có doanh số cao nhất 

 SELECT productline
,sum(sales) Revenue
,count(ordernumber) Frequency
FROM dbo.sales_data_sample
WHERE city = 'San rafael'
GROUP BY productline
ORDER BY 2 desc 
--> Như dự đóan Classic Cars là sản phẩm tạo ra nhiều doanh số nhất

-- Ai là khách hàng tốt nhất của chúng tôi? Từ đó đưa ra các ưu đãi hợp lí cho khách hàng (sử dụng mô hình RFM)
DROP TABLE IF EXISTS #rfm
;WITH rfm as			
(	
	SELECT 
	customername
	,sum(sales) Monetary
	,avg(sales) AvgMonetary
	,count(ordernumber) Frequency
	,max(orderdate) last_orderdate
	,DATEDIFF(DD,max(orderdate),(select max(orderdate) from dbo.sales_data_sample) ) Recency
	FROM dbo.sales_data_sample 
	group by customername 
)
, rfm_calc as (
	SELECT *
	,NTILE(4) OVER(order by recency desc) rfm_recency
	,NTILE(4) OVER(order by frequency) rfm_frequency
	,NTILE(4) OVER(order by Monetary) rfm_Monetary
	FROM rfm 
 )
SELECT * 
,rfm_recency+rfm_frequency+rfm_Monetary rfm_cell
,concat(rfm_recency,rfm_frequency,rfm_Monetary) rfm_rank
INTO #rfm
FROM rfm_calc

SELECT 
 CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
-- các case RFM em tham khảo ạ
	case 
		when rfm_rank in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers' 
		when rfm_rank in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away --> Nên tạo những ưu đãi mạnh mẽ để giữ chân khách hàng, đề xuất dựa trên các giao dịch mua trước đây
		when rfm_rank in (311, 411, 331) then 'new customers' --> Sử dụng ưu đãi để thu hút và quan tâm đến họ 
		when rfm_rank in (222, 223, 233, 322) then 'potential churners' --> Cung cấp các chương trình thành viên, giới thiệu sản phẩm khác
		when rfm_rank in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points) --> Tao nhận diện thương hiệu, cung cấp bản dùng thử free, upsell
		when rfm_rank in (433, 434, 443, 444) then 'loyal' --> Upsell các sản phẩm có giá trị cao hơn, yêu cầu đánh giá
	end rfm_segment 
FROM #rfm 

-- Sản phẩm nào thường được bán cùng nhau nhất?	
--SELECT * FROM dbo.sales_data_sample WHERE ORDERNUMBER = 10411 Kiểm tra mỗi đơn hàng thường có bao nhiêu loại sản phẩm
SELECT DISTINCT ordernumber, STUFF(
	(SELECT ','+productcode
	FROM dbo.sales_data_sample p 
	WHERE ordernumber in (
		SELECT ordernumber
		FROM (
		SELECT ordernumber, count(*) rn
		FROM dbo.sales_data_sample
		WHERE status = 'Shipped'
		GROUP BY ordernumber 
		) m
		WHERE rn =2  
	)	
	and p.ordernumber = s.ordernumber
	FOR xml path ('')) 
	,1,1,'') Productcodes
FROM dbo.sales_data_sample s
ORDER BY 2 desc 
-- Sản phẩm S18_2325, S24_1937 Chúng ta có thể tạo ra chương trình khuyến mãi hoặc chiến dịch quảng cáo cho 2 sản phẩm đó được bán cùng nhau


