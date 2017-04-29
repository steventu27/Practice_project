import re
import requests
import pandas as pd
from bs4 import BeautifulSoup
from fake_useragent import UserAgent

def getHTMLText(url,code="ascii"):
    try:
        ua=UserAgent()
        headers1={'User-Agent': 'ua.random'} # Use random header to imitate human behaviour
        r = requests.get(url,headers=headers1)
        r.raise_for_status()
        r.encoding = code
        return r.text
    except:
        return "getHTML error"

def getCourseDetail(url):
    html=getHTMLText(url)
    soup=BeautifulSoup(html,"html.parser")
    for course in soup.select('div[class="course-info expandable"]'):
        course_info={}
        course_info["course_code"]=course("strong")[0].text[:-1] # course_code
        course_info["course_web"]='=HYPERLINK("{}", "click here")'.format(course.select('a[class="courselink"]')[0]["href"]) # course_web
        course_info["course_name"]=''.join(re.findall("</strong> (.*) <span",str(course))) # course_name
        course_info["course_units"]=''.join(re.findall("[0-9.]+",course("span")[0].text))  # course_units
        course_info["course_intro"]=course.select('div[class="catalogue"]')[0].text # course_introduction

        course_time=[]
        for i,j,k in zip(course.find_all("td",attrs="type"),course.find_all("td",attrs="days"),course.find_all("td",attrs="time")):
            temp=i.text+" "+j.text+" "+k.text
            course_time.append(temp)
        course_info["course_time"]=course_time  # course class time

        course_prof=[]
        for prof in course.select('td[class="instructor"]'):
            course_prof.append(prof.text)
        if '' in course_prof:
            course_prof.remove('')
        course_info["course_prof"]=course_prof #course_professor

        courseList.append(course_info)
    return courseList

motherurl="http://classes.usc.edu/term-20173/classes/"
dpList=["ise","fbe","math","dso","csci","ee"]  # department of quant 
courseList=[]

for dp in dpList:
    url=motherurl+dp
    courseList=getCourseDetail(url)

df=pd.DataFrame(courseList)
df.to_excel("/Users/Steven/Desktop/USC_quant_class_2017fall.xlsx")
