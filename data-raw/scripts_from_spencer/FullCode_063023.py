# MFJD Water Temp Forecasting and Alert Code

# to improve: module/function format; discharge forecast(linear interp currently); get yesterday's data from Keeny2; threshold alert, plot

# 7/6/23 - code now uses yesterday's forecasted air temps as yesterday's actual air temps
# scaler saving issue resolved- now most recent scaler/classifier are being used

# Several steps in code that should be set up as individual modules - errors as oof 6/30/23

## STEPS
#1. Get USGS Data
#2. Get Met Data
#3. Use 1/2 to Forecast
#4. Catalog Forecast and send alters

## General Inputs

email='nyes'

Tmax_thresh=25

## 1. Get USGS Data

#INPUTs
#list of gages to be analyzed
gage_list=r'U:\Internal Share\Water Program\Flow Science+Projects (not ISWRs)\WaterTemperature\WaterTemperatureMonitoring\Realtime\USGS\MFJD.xlsx'
sheet_in= 'Full_List'

#Daily input data storage
FlowTemp_out_storage=r'U:\Internal Share\Water Program\Code\Python\Monitoring\SiteSpecificWaterTemp\MFJD\ODFW_2023\DataStorage\Yesterday.xlsx'

#Forecast storage
prediction_storage=r'U:\Internal Share\Water Program\Code\Python\Monitoring\SiteSpecificWaterTemp\MFJD\ODFW_2023\DataStorage\MFJD_2023_ForecastOutput.xlsx'

#email list
email_list=r'U:\Internal Share\Water Program\Code\Python\Monitoring\SiteSpecificWaterTemp\MFJD\ODFW_2023\email\Contacts_2023.xlsx'

#Temporary email attachment storage
daily_results_storage = r'U:\Internal Share\Water Program\Code\Python\Monitoring\SiteSpecificWaterTemp\MFJD\ODFW_2023\email\attachment.csv'

# first import the functions for downloading data from NWIS
import dataretrieval.nwis as nwis
#from datetime import datetime
import datetime
from datetime import datetime as dt
from datetime import date
from datetime import timedelta
import pandas as pd
import numpy as np
import openpyxl
import time

## START - no more inputs

# import gage list
data_df = pd.read_excel(gage_list, engine='openpyxl', sheet_name= sheet_in)#excel to df

# specify the USGS site code for which we want data.
sites = data_df['Gage #'][:].astype(str)

##dates
yesterday = date.today() - datetime.timedelta(days=1)
today_minus3 = date.today() - datetime.timedelta(days=3)
today = date.today()

#build df of dates
dates = pd.DataFrame( data=None, columns= ['date','day','month'], index = np.arange(0,9))
for a in dates.index:
    dates['date'][a]= today_minus3 + datetime.timedelta(a)#
    dates['day'][a] =dates['date'][a].day
    dates['month'][a] = dates['date'][a].month

# setup output
summary_stats = pd.DataFrame( data=None, columns= ['site','name', 'lat', 'long','start_year','years','7dayEndDate','MaxDailyMax','ExceedanceProb_7DaySearch'], index = np.arange(0,len(sites)))
summary_stats.site[:]=sites

### Loop through gages
for x in summary_stats.index:

    while True:
        try:
            df = nwis.get_record(sites=summary_stats.site[x], service='iv', start=str(today_minus3), end=str(today))#, parameterCd='00010','00060')  # parameterCd='00060' for discharge

            break  # If the above succeeds, we break here
        except MemoryError:
            # If there is an IndexError, wait a second then the loop will repeat.
            # browser.quit()
            time.sleep(1)
        except ValueError:
            # If there is an IndexError, wait a second then the loop will repeat.
            # browser.quit()
            time.sleep(1)

    #proceede only if df isnt empty

    if len(df)>0:
        ##datetime processing
        df.reset_index(inplace=True)
        df = df.rename(columns = {'index':'DateTime'})

        var=df.datetime.astype(str)
        var2=var.str.split(" ", n = 1, expand = True)

        df['date']=""
        df['time']=""
        df['date_datetime']=""

        #assign
        df['date']=var2[0][:]
        df['time']=var2[1][:]

# convert date again
df['date_datetime']=""
for k in df.index:
    df['date_datetime'][k]=(dt.strptime(df['date'][k], '%Y-%m-%d')).date()

# Summarize
FlowTemp_out=dates
FlowTemp_out['MeanQ']=""
FlowTemp_out['MeanT']=""
FlowTemp_out['MaxT']=""
FlowTemp_out['AirMax']=""
FlowTemp_out['AirMin']=""
FlowTemp_out['Julian']=""

#get daily stats from 15 min USGS data
for j in [0,1,2,3]:
            date=FlowTemp_out.date[j]

            #check if not empy
            if len(df['00060'][df['date_datetime']==date]) >0 :

                # removed temp catalog because gage wasnt working
                #FlowTemp_out['MaxT'][j]=max(df['00010'][df['date_datetime']==date])
                #FlowTemp_out['MeanT'][j] = np.mean(df['00010'][df['date_datetime'] == date])
                FlowTemp_out['MeanQ'][j]=np.mean(df['00060'][df['date_datetime']==date])

## 2  Get Met Data

#documentation
#https://weather-gov.github.io/api/general-faqs

from urllib.request import urlopen
import json
from datetime import datetime
import requests

"https://api.weather.gov/points/44.666111,-118.920833" #Keeny 2
# open in browser and get grid points to input below
#https://weather-gov.github.io/api/gridpoints#:~:text=What's%20a%20gridpoint%3F,of%20these%202.5km%20squares.

# data api links
link_met = "https://api.weather.gov/gridpoints/PDT/119,54"

#Read data from Met site
f_met = urlopen(link_met)
myfile_met = f_met.read()
data_met = myfile_met.decode("utf-8")
dic_weather_forecast = json.loads(data_met)

# get dates
#today+5days
dates=FlowTemp_out.date[3:9]

for d1 in dates:
    for k1 in dic_weather_forecast['properties']['maxTemperature']['values']:
        if datetime.strptime(k1['validTime'].split('T')[0], '%Y-%m-%d').date() == d1:
            #max_temp = round((k1['value'] * 9 / 5) + 32, 2)
            max_temp = k1['value'] #in Celsius
            max_temp = (max_temp * 1.8) + 32
            FlowTemp_out['AirMax'][FlowTemp_out['date']==d1]= max_temp

    for k1 in dic_weather_forecast['properties']['minTemperature']['values']:
        if datetime.strptime(k1['validTime'].split('T')[0], '%Y-%m-%d').date() == d1:
            #min_temp = round((k1['value'] * 9 / 5) + 32, 2)
            min_temp = k1['value'] #in Celsius
            min_temp = (min_temp*1.8)+32
            FlowTemp_out['AirMin'][FlowTemp_out['date'] == d1] = min_temp

#Retrieve yesterdays FlowTemp_out
FlowTemp_out_old=pd.read_excel(FlowTemp_out_storage, engine='openpyxl', sheet_name= 'Sheet1')#excel to df

# Save FlowTemp_out to populate data for Ann
FlowTemp_out.to_excel(FlowTemp_out_storage, engine='openpyxl', sheet_name= 'Sheet1')#excel to df

### 3 Run Forecast

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.optimize as opt
import pylab
import math
import pickle
from joblib import dump, load
import datetime as dt
from sklearn.linear_model import LinearRegression

#Julian Date
for i in FlowTemp_out.index:
    FlowTemp_out['Julian'][i] = FlowTemp_out.date[i].strftime('%j')

# Discharge Forecast
x = np.array([-3,-2,-1]).reshape((-1, 1))
y = np.array(FlowTemp_out.MeanQ[0:3])
model = LinearRegression().fit(x, y)
x_pred=np.array([0,1,2,3,4,5]).reshape((-1, 1))
y_pred = model.predict(x_pred) # predict out next 5 days
FlowTemp_out.MeanQ[3:9]=y_pred

# Load ANN
classifier_mfjd = load('U:\Internal Share\Water Program\Code\Python\WaterTemperature\MFJd\MFJD.joblib')
scaler_mfjd = load('U:\Internal Share\Water Program\Code\Python\WaterTemperature\MFJd\MFJD_scaler.joblib')

# input format
#X_M1 = np.transpose(np.array([Q, Jul, Air_Max, Air_Min, Q_m1, Air_Max_m1, Air_Min_m1]))  # , Air_Min]))# arrange data

dates = pd.DataFrame( data=None, columns= ['date','day','month'], index = np.arange(0,9))

X_pred= pd.DataFrame( data=None, columns= np.arange(0,7), index = np.arange(0,6))
X_pred[0][0:6]=FlowTemp_out.MeanQ[3:9]#Q
X_pred[1][0:6]=FlowTemp_out.Julian[3:9]
X_pred[2][0:6]=FlowTemp_out.AirMax[3:9]
X_pred[3][0:6]=FlowTemp_out.AirMin[3:9]

#minus 1 day
X_pred[4][0:6]=FlowTemp_out.MeanQ[2:8]
X_pred[5][0:6]=FlowTemp_out.AirMax[2:8]
X_pred[6][0:6]=FlowTemp_out.AirMin[2:8]

#yesterday-
# use today as dummy data for now
#X_pred[5][0]=X_pred[5][1]
#X_pred[6][0]=X_pred[6][1]

#use yesterday's stored forecast
yes_day=(date.today()).day-1# day integer
X_pred[5][0]= FlowTemp_out_old['AirMax'][FlowTemp_out_old['day'] == yes_day].values
X_pred[6][0]=FlowTemp_out_old['AirMin'][FlowTemp_out_old['day'] == yes_day].values


# if yesterdays data not available use today as estimate for yesterdays air temps
if np.isnan(X_pred[5][0]) == True:
     X_pred[5][0]=X_pred[5][1]
if np.isnan(X_pred[6][0]) == True:
     X_pred[6][0]=X_pred[6][1]

# inputs cannot be float, must be int, but need to convert to float first
X_pred=X_pred.astype(float)
X_pred=100*X_pred
X_pred = X_pred.astype(int)


# Scale
X_final1=scaler_mfjd.transform(X_pred)
#Predice
y_pred = classifier_mfjd.predict(X_final1)

#rescale
y_pred_100=np.divide(y_pred,100)

# Rearrange
out=FlowTemp_out['date'][3:9]
out=out.to_frame().reset_index()
out['MaxT [C]']=""
out['MaxT [C]']=y_pred_100
out=out.drop(['index'], axis=1)
out['MaxT [C]'][:]=round(out['MaxT [C]'][:],2)


# save table for email
out.to_csv(daily_results_storage)

# save for analysis
prediction = pd.read_excel(prediction_storage, engine='openpyxl', sheet_name= 'Sheet1')#excel to df
prediction=prediction.drop(['Unnamed: 0'], axis=1)
var=[today, round(y_pred_100[0],2), round(y_pred_100[1],2), round(y_pred_100[2],2),round(y_pred_100[3],2),round(y_pred_100[4],2),round(y_pred_100[5],2)]
prediction.loc[len(prediction)]=var
prediction.to_excel(prediction_storage, engine='openpyxl', sheet_name= 'Sheet1')#excel to df

#### Email

import win32com.client as win32 #email

# import recipient list
contacts_df = pd.read_excel(email_list, engine='openpyxl', sheet_name= 'Sheet1')#excel to df

if email=='yes':
            # loop through unique contacts to determine indices to send
            for n in contacts_df.contact:

                #email
                ####################################
                outlook = win32.Dispatch('outlook.application')
                mail = outlook.CreateItem(0)
                mail.To = n
                mail.Subject = 'Middle Fork John Day Water Temperature Forecast'
                mail.Body = 'See attached summary of predicted maximum daily water temperatures @ USGS 14043840 MF JOHN DAY RIVER ABV CAMP CREEK, NR GALENA, OR'

                # To attach a file to the email (optional):
                mail.Attachments.Add(daily_results_storage)
                mail.Send()
