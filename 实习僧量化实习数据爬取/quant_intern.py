# code utf-8

import re
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

def getTotalPositon(url,n): # n为获取页面数量
    position=[] #建立岗位信息列表
    for i in range(1,n):
        suburlList=[] # 建立单个网页岗位信息个数
        html=getHTMLText(url+str(i))
        soup=BeautifulSoup(html,'html.parser')
        for j in soup.select('a[target="_blank"]'):
            tem=j["href"]  # 获取 a 标签下target="_blank"中的"href"内容
            suburlList.append(''.join(e for e in re.findall("^/intern.*",tem) ) )  #在 tem 中寻找 intern 开头的子域
        while "" in suburlList:
            suburlList.remove("")  # 除去空字符串

        item_num=len(suburlList)   # 查看页面含有多少个岗位
        for p in range(item_num):
            suburl=suburlList[p]
            motherurl="https://www.shixiseng.com"
            url1=motherurl+suburl # 获得单个岗位的网址
            position.append(getPositionDetail(url1,soup,p))

    return position

def getPositionDetail(url,soup,p):
    info={}
    info["岗位名称"]=soup("h3")[:10][p].text
    info["单位名称"]=soup.select('a[class="company_name"]')[p].text  # 这两个信息是在pg1页面中的信息
    html=getHTMLText(url)
    soup=BeautifulSoup(html,'html.parser')  # 进入单个岗位的详细介绍
    info["更新时间"]=soup.select('span[class="update_time"]')[0].text[:10]
    info["薪资"]=''.join(re.findall("[0-9\-]+/天",soup.select('span[class="daymoney"]')[0].text))
    info["工作地点"]=soup.select('span[class="city"]')[0].text
    info["学位要求"]=soup.select('span[class="education"]')[0].text[:2]
    info["工作时长"]=soup.select('span[class="month"]')[0].text
    info["岗位职责"]=''.join(re.findall("岗位职责：(.*)任职要求",soup.select('div[class="dec_content"]')[0].text))
    info["任职要求"]=''.join(re.findall("任职要求：(.*)",soup.select('div[class="dec_content"]')[0].text))
    return info

def main():
    url="https://www.shixiseng.com/interns?k=%E9%87%8F%E5%8C%96&c=%E5%85%A8%E5%9B%BD&s=0,0&d=&m=&x=&t=zh&ch=&p="
    n=6
    positionList=getTotalPositon(url,n)
    df=pd.DataFrame(positionList)
    df.to_excel("/Users/Steven/Desktop/quant_position.xlsx")

if __name__ == '__main__':
    main()
