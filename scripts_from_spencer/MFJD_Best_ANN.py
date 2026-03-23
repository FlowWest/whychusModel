#1/5/23 Sawaske

# code to reproduce and save "best " ANN model from iteration code and analysis of output
# for MFJD as of 6/30/23  X_M1 = np.transpose(np.array([Q, Jul, Air_Max, Air_Min, Q_m1, Air_Max_m1, Air_Min_m1]))#,tar_m1]))#, tar_m1]))  # , Air_Min]))# arrange data

# Data
# Met data from KeenyTwo RAWS Station
# Q,Twater from USGS mfjd abv camp creek

# import Pandas (data manipulation) and Matplotlib (trending)
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.optimize as opt
import pylab
import math
import pickle
from joblib import dump, load

import datetime as dt


# notes
# for KNN, inputs must be integers- work around is to multiply all by 100 then divide result by 100
# met data from: https://gis.ncdc.noaa.gov/maps


## INPUT DATA

# data locations
#file_data = r"U:\Internal Share\Water Program\Flow Science+Projects (not ISWRs)\WaterTemperature\WaterTemperatureBasedFlowTargets\MFJD\Data\USGS.txt"
#met_data = r"U:\Internal Share\Water Program\Flow Science+Projects (not ISWRs)\WaterTemperature\WaterTemperatureBasedFlowTargets\MFJD\Data\2407445.csv"
file_data = r"scripts_from_spencer/2022_Data/FlowandTemp.csv"
met_data = r"scripts_from_spencer/2022_Data/Met.csv"

# output names and locations
output_dir = r"U:\Internal Share\Water Program\Code\Python\WaterTemperature\MFJd\Output"
output_name = "\ANN_selected.csv"

# plot
plot = 'yes' # anything other than yes=no plot

# month range
m_start=6 #June
m_stop =9 # Septempber

# ANN variables
h=5# max number of hidden layers
#hidden=np.linspace(1,h,h).astype(int)# last two must match

p=.2 # testing percentage(train vs test)
iterations = 1000 # max number of solver iterations

lag='yes'
solv='lbfgs'

########## NO INPUTS BELOW

#################### Data Prep
#read in data
df= pd.read_csv(file_data) # flow and water temp data
df_met=pd.read_csv(met_data)#met data

#build new reduced df
df_red = pd.DataFrame()
df_red['date'] = df['20d']; df_red['Q'] = df['14n']; df_red['Tmax'] = df['14n.1']; df_red['Tmin'] = df['14n.3'];df_red['Tmean'] = df['14n.2']
df_red['Air_Max']=""
df_red['Air_Min']=""
df_red['Air_Mean']=""
df_red['Date2'] = ""#new date column to match met data format


for i in df_red.index:
    df_red.Date2[i] = dt.datetime.strptime(df_red.date[i], '%m/%d/%Y')
    df_red.Date2[i] = df_red.Date2[i].strftime('%Y-%m-%d')
'Jun 09,2011'


# add met data
for i in df_red.index:
    date1=df_red.date[i]
    tmet_max= df_met['Tmax'][df_met['Date'] == date1]
    tmet_min= df_met['Tmin'][df_met['Date'] == date1]
    tmet_mean= df_met['Tmean'][df_met['Date'] == date1]

    if len(tmet_max)>0:
        df_red.Air_Max[i]=tmet_max.iloc[0]
    if len(tmet_min)>0:
        df_red.Air_Min[i]=tmet_min.iloc[0]
    if len(tmet_mean) > 0:
        df_red.Air_Mean[i] = tmet_mean.iloc[0]

#remove nans
df_red.replace('', np.nan, inplace=True)# set all empties to nan

df_red = df_red.astype('str')
df_filt = df_red[df_red['Tmax'] != 'nan']
df_filt = df_filt[df_filt['Q'] != 'nan']
df_filt = df_filt[df_filt['Air_Max'] != 'nan']
df_filt = df_filt[df_filt['Air_Min'] != 'nan']

# get months, years, days, julian
df_filt['month'] = pd.DatetimeIndex(df_filt['date']).month
df_filt['day'] = pd.DatetimeIndex(df_filt['date']).day
df_filt['year'] = pd.DatetimeIndex(df_filt['date']).year

#Julian Date
df_filt['Julian']= ""
for i in df_filt.index:
    my_date = dt.datetime.strptime(df_filt.Date2[i], '%Y-%m-%d')
    jld_str = my_date.strftime('%j')
    df_filt['Julian'][i] = int(jld_str)

# reduce to selected months
df_final = df_filt[(df_filt['month'] >= m_start) & (df_filt['month'] <= m_stop)]

# Single Day Version
tar_0=df_final.Tmax
Q=df_final.Q
Jul=df_final.Julian
Air_Max=df_final.Air_Max
Air_Min=df_final.Air_Min

# Arrange matrix for KNN
X_0 = np.transpose(np.array([Q, Jul, Air_Max, Air_Min]))  # , Air_Min]))# arrange data

#Multiple Day Version-reduce lengths by one
tar_M1=df_final.Tmax[1:len(df_final.Tmax)]
Q=df_final.Q[1:len(df_final.Tmax)]
Jul=df_final.Julian[1:len(df_final.Tmax)]
Air_Max=df_final.Air_Max[1:len(df_final.Tmax)]
Air_Min=df_final.Air_Min[1:len(df_final.Tmax)]
#lag days
Air_Max_m1=df_final.Air_Max[0:len(df_final.Tmax)-1]
Air_Min_m1=df_final.Air_Min[0:len(df_final.Tmax)-1]
Q_m1=df_final.Q[0:len(df_final.Tmax)-1]
tar_m1=df_final.Tmax[0:len(df_final.Tmax)-1] # previous days h20 temp

#only indep. vars
X_M1 = np.transpose(np.array([Q, Jul, Air_Max, Air_Min, Q_m1, Air_Max_m1, Air_Min_m1]))#,tar_m1]))#, tar_m1]))  # , Air_Min]))# arrange data
# indep. and dep vars(tar=water temp)
X_M1_tar = np.transpose(np.array([Q, Jul, Air_Max, Air_Min, Q_m1, Air_Max_m1, Air_Min_m1, tar_m1]))#, tar_m1]))  # , Air_Min]))# arrange data

##### ANN

## make outputs
#legth of output
output = pd.DataFrame(data=None, columns=['hidden layers','solver', 'lag', 'R2', 'RMSE'], index=[1])
output_loc = output_dir + output_name

c=1#count

if lag == 'no':# no lags
    X=X_0
    tar=tar_0
if lag == 'yes':# indep var lag
    X=X_M1
    tar=tar_M1
if lag == 'yes_tar':# indep and dep var lag
    X=X_M1_tar
    tar=tar_M1

# inputs cannot be float, must be int, but need to convert to float first
X=X.astype(float)
tar=tar.astype(float)
X=100*X
tar=100*tar

X = X.astype(int)
tar = tar.astype(int)

#Select Test and Train sets
from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, tar, test_size= p)

X_train_store=X_train
X_test_store=X_test

#scale data-Standard
from sklearn.preprocessing import StandardScaler
scaler = StandardScaler()
scaler.fit(X_train)
X_train = scaler.transform(X_train)
X_test = scaler.transform(X_test)

#### ITERATION VERSION TO FIND BEST NEIGHBOR COUNT

#predict - iteration version to determine best neighbor count
from sklearn.neural_network import MLPRegressor
#solver='lbfgs', alpha=1e-5,

j=h

hidden_layer= (np.min(X.shape)+1)* np.ones(j).astype(int)#size is set at number of variables in X, +1 for bias
classifier = MLPRegressor(hidden_layer_sizes=hidden_layer,max_iter=iterations, solver=solv) # single layer
classifier.fit(X_train, y_train)
y_pred = classifier.predict(X_test)

#rescale
y_pred_100=np.divide(y_pred,100)
y_test_100 = np.divide(y_test, 100)

SSres = np.sum((y_pred_100 - y_test_100) ** 2)
SStot = np.sum((y_test_100 - np.average(y_test_100)) ** 2)
R2 = 1 - (SSres / SStot)
RMSE =  (np.divide(SSres,len(y_pred)))**0.5

# #output
output['hidden layers'][c] = j
output['lag'][c] = lag
output['solver'][c] = solv
output['R2'][c] = R2
output['RMSE'][c] = RMSE

if plot=='yes':
    pylab.figure(j)
    x = np.linspace(0, 1.25 * np.max(y_pred), 50)
    pylab.plot(y_pred_100, y_test_100, 'o', label='data R^2= ' + str(round(R2, 2)))
    pylab.plot(x, x, 'r--', label='1/1')

    pylab.xlim(0, 1.25 * np.max(y_pred_100))
    pylab.ylim(0, 1.25 * np.max(y_pred_100))
    pylab.legend(loc='best', numpoints=1)
    pylab.title(['ANN ', str(j), ' hidden layers'])
    pylab.ylabel('Data - Max Daily T [C]')
    pylab.xlabel('Model- Max Daily T [C]')

    c=c+1

    # pylab.figure(j+1)
    # pylab.plot(output['hidden layers'],output['R2'],'o')
    # pylab.ylabel('R2')
    # pylab.xlabel('Hidden Layers')
    # pylab.ylim(0, 1)

# Export
output.to_csv(output_loc)
#print(classifier)

# # Save Model
# s=pickle.dumps(classifier)
# classifier2=pickle.loads(s)
# classifier2.predict(X_test[0,:])

# Save Model v2
dump(classifier, r'U:\Internal Share\Water Program\Code\Python\WaterTemperature\MFJd\MFJD.joblib')
classifier3 = load(r'U:\Internal Share\Water Program\Code\Python\WaterTemperature\MFJd\MFJD.joblib')

dump(scaler, r'U:\Internal Share\Water Program\Code\Python\WaterTemperature\MFJd\MFJD_scaler.joblib')
scaler3 = load(r'U:\Internal Share\Water Program\Code\Python\WaterTemperature\MFJd\MFJD_scaler.joblib')

test11= scaler3.transform(X_train_store)
test12= scaler3.transform(X_train_store)
test13= scaler3.transform(X_train_store)
#
# # save the scaler
# from pickle import dump
# dump(scaler, open('scaler.pkl', 'wb'))