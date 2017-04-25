import requests
import pandas as pd
from bs4 import BeautifulSoup
from fake_useragent import UserAgent

def getHTMLText(url,code="utf-8"):
    try:
        ua=UserAgent() #使用随机header，模拟人类
        headers1={'User-Agent': 'ua.random'}#使用随机header，模拟人类
        r = requests.get(url,headers=headers1)
        r.raise_for_status()
        r.encoding = code
        return r.text
    except:
        return "getHTML error"

def getTotalHouse(url,n): # n为获取页面数量
    house=[] #建立房屋信息列表
    for i in range(1,n):
        html=getHTMLText(url+str(i))
        soup=BeautifulSoup(html,'html.parser')
        for tem in soup.find_all('a',attrs="img")[0:30]: #获取 class="img" 下的a标签前30个房屋信息
            suburl=tem['href']   #获取各自的href域名内容
            house.append(getHouseDetail(suburl))
    return house

def getHouseDetail(url):
    info={} # 建立房屋细节字典
    html=getHTMLText(url)
    soup=BeautifulSoup(html,'html.parser')
    bound=len(soup.select('.content li span'))  # content 标签下的 li 标签下的 span 标签的长度,就是 key 的个数
    info["总价"]=soup.select('span[class="total"]')[0].text  #获取span 标签 class="total" 的内容
    # 或者 info["总价"]=soup.find_all("span",attrs="total")[0].text
    info["小区名称"]=soup.select('a[class="info"]')[0].text
    info["所在区域(大)"]=soup.select('a[target="_blank"]')[3].text
    info["所在区域(小)"]=soup.select('a[target="_blank"]')[4].text
    for n in soup.select('.content li')[:bound-1]:
        a=n.text  #text 包含了键值对
        key,value=a[:4],a[4:]  #分开选择
        info[key]=value
    return info

def main():
    url='http://sz.lianjia.com/ershoufang/pg'
    n=5
    houseList=getTotalHouse(url,n)
    temp=pd.DataFrame(houseList)    #pandas 大法
    temp.to_excel("/Users/Steven/Desktop/house_info_sz.xlsx")

if __name__ == '__main__':
    main()
