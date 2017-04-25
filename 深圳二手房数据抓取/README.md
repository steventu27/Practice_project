# Secondhand house info in Shenzhen
## Data Source http://sz.lianjia.com/ershoufang/
## Process:
* Find the mother page info, concluding 30 houses' info. We can gain every house's html
* In each son page, extract the info you want into a dict
* DataFrame it and export into excel
