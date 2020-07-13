/* Import chicago crime data by year as CSV file*/

proc import out = chicago_crime2016
	datafile = '/home/ajuliang940/sasuser.v94/STAT 403/Data/Chicago16.csv'
	dbms = csv replace;
	getnames = yes; 
run;

proc import out = chicago_crime2017
	datafile = '/home/ajuliang940/sasuser.v94/STAT 403/Data/Chicago17.csv'
	dbms = csv replace;
	getnames = yes;
run;

proc import out = chicago_crime2018
	datafile = '/home/ajuliang940/sasuser.v94/STAT 403/Data/Chicago18.csv'
	dbms = csv replace;
	getnames = yes; 
run;

/*add date and time formats for each uploaded datasets*/
data chicago2016_time;
set chicago_crime2016;
Date_n = input(Date, MMDDYY10.);
Time_n = input(Time, time.);
Month = input(Date, MMDDYY10.);
drop n;
format Date_n mmddyy10.;
format time_n HHMM.;
format Month MONYY.;
Population = 2720275;

data chicago2017_time;
set chicago_crime2017;
Date_n = input(Date, MMDDYY10.);
Time_n = input(Time, time.);
Month = input(Date, MMDDYY10.);
format Date_n mmddyy10.;
format time_n HHMM.;
format Month MONYY.;
Population = 2716450; /*census bureau*/
drop X;

data chicago2018_time;
set chicago_crime2018;
Date_n = input(Date, MMDDYY10.);
Time_n = input(Time, time.);
Month = input(Date, MMDDYY10.);
format Date_n mmddyy10.;
format time_n HHMM.;
format Month MONYY.;
Population = 2687700; 
drop X;
run;

/*Combine datasets by date*/
proc sort data = chicago2016_time;
by Date_n;
proc sort data = chicago2017_time;
by Date_n;
proc sort data = chicago2018_time;
by Date_n;
data chicago_crimes_merge;
merge chicago2016_time chicago2017_time chicago2018_time;
by Date_n;
run;

/*Add Seasons and weather type*/
data chicago_crimes;
set chicago_crimes_merge;
drop X;
if month(Date_n) >= 3 and month(Date_n) <= 5 then season = 'Spring';
else if month(Date_n) >= 6 and month(Date_n) <= 8 then season = 'Summer';
else if month(Date_n) >= 9 and month(Date_n) <= 11 then season = 'Fall';
else season = 'Winter';
if season = 'Spring' or season = 'Summer' then Weather = 'warm';
else Weather = 'cool'; /*winter and fall are chillier*/
run;


/***********************************************************/


/*count incidents by date*/
proc freq data=chicago_crimes noprint;
tables date_n*season*weather/ nopercent nocum
out = freq;
data chicago_num; /*rename count of crime incidents*/
set freq;
number_of_crimes = count;
drop count percent;
run;

/*count arrests made by date*/
proc freq data=chicago_crimes noprint;
tables date_n*weather*Arrest/ nopercent nocum
out = freq_arrest;
where Arrest ='TRUE';
data chicago_arrests; /*rename count to number of arrests*/
set freq_arrest;
number_of_arrests = count; 
drop count percent;
run;

/*join arrest and crime counts to calculate percents*/
proc sort data = chicago_num;
by date_n;
proc sort data = chicago_arrests;
by date_n;
data chicago_arrest_ratio;
merge chicago_num chicago_arrests;
by Date_n;
if missing(number_of_arrests) then number_of_arrests = 0;
pct = number_of_arrests/number_of_crimes;
Arrest_Percentage = pct* 100;
run;

/*timeplot for arrest percentage by date*/
axis1 label= ('Date' h=1 f=swiss);
axis2 label= ('Arrest Percentage' h=1 f=swiss);
symbol interpol= join;
proc gplot data = chicago_arrest_ratio;
plot arrest_percentage*Date_n / haxis= axis1 vaxis= axis2;
run; 

proc print data = chicago_arrest_ratio;
where Date_n between '28Dec2016'd and '28Feb2017'd;
run;

/*time plot for january 2017*/
axis1 label= ('Date' h=1 f=swiss);
axis2 label= ('Arrest Percentage' h=1 f=swiss);
symbol interpol= join;
proc gplot data = chicago_arrest_ratio;
plot arrest_percentage*Date_n / haxis= axis1 vaxis= axis2;
where Date_n between '01Dec2016'd and '28Feb2017'd;
run; 


/*t-test*/
proc ttest data = chicago_arrest_ratio side=l plots=box;
class weather;
var arrest_percentage;
run;

/**************************************************************************/

/*the most common crimes*/
proc freq data = chicago_crimes order=freq noprint;
tables Primary_type / nocum
out = freq_type;
run;

/*delete other offense since it is too broad and it has too many descriptions*/
data top_crimes;
set freq_type;
if Primary_Type = 'OTHER OFFENSE' then delete;
proc print;
run;


/*pie chart for crimes*/
proc gchart data = top_crimes;
title 'The Most Reported Crimes in Chicago 2016-2018';
pie primary_type/ sumvar= count percent= inside slice= arrow;
run;

/*narrow the main dataset to the crimes from the pie chart*/
data chicago_most_frequent;
set chicago_crimes;
where Primary_Type = 'THEFT'| Primary_Type = 'BATTERY' |Primary_Type = 'CRIMINAL DAMAGE' |
Primary_Type = 'MOTOR VEHICLE THEFT' |Primary_Type = 'ASSAULT' | Primary_Type = 'DECEPTIVE PRACTICE' |
Primary_Type = 'ROBBERY' |Primary_Type = 'NARCOTICS'|Primary_Type = 'BURGLARY';
run;


/*Contingency table for the most common arrest crimes and arrest*/
proc freq data = chicago_most_frequent order= freq;
title 'The Most Reported Crimes in Chicago by Arrest';
tables Primary_type*arrest / nocum chisq expected deviation nopercent out = arrest_freq outpct plots=mosaicplot;
run;

/* bar graph on arrest status by crime*/
proc sgplot data = arrest_freq;
title 'Bar Graph on Arrest Percentages in Primary Types';
vbar Primary_type / response=pct_row datalabel;
where arrest = 'TRUE';
run;



/* Contingency tables for the most common arrest crimes and arrest status separated by weather*/
proc sort data = chicago_most_frequent;
by weather;
proc freq data = chicago_most_frequent order= freq;
title 'The Most Reported Crimes in Chicago by Arrest';
tables Primary_type*arrest / nocum chisq expected deviation nocol out = arrest_freq2 outpct;
by weather;
run;


/* bar graph on arrest percentages by primary type grouped by weather (from the tables above) */
proc sgplot data = arrest_freq2;
title 'Bar Graph on Arrest Percentages in Primary Types by Weather';
vbar Primary_type / response=pct_row group= weather groupdisplay=cluster datalabel;
where arrest = 'TRUE';
run;



/*contingency table on primary types of crime and weather when arrests have been made*/
proc freq data = chicago_most_frequent order= freq;
title 'The Most Reported Crimes in Chicago by temperature';
tables Primary_type*weather / chisq expected deviation nopercent nocol out = temp_freq outpct;
where arrest = 'TRUE';
run;


/*bar graph on arrest percentage by crime by weather*/
proc sgplot data = temp_freq;
title 'Bar Graph on Arrest Percentages by Weather';
vbar Primary_type / group = weather groupdisplay=cluster response= pct_row;
run;





/***************************************************************/
/*domestic incidents by date*/
proc freq data=chicago_crimes noprint;
tables date_n*temperature*Domestic/ nopercent nocum
out = domestic_freq;
where Domestic = 'FALSE';
run;


/*frequency of domestic crime incidents*/
data chicago_domestic;
set domestic_freq;
number_of_domestics = count;
drop count percent;
run;


/*date and domestic arrests*/
proc freq data=chicago_crimes noprint;
tables date_n*Domestic*temperature*Arrest/ nopercent nocum
out = freq_domestic_arrest;
where Arrest ='TRUE' and Domestic = 'FALSE';
run;

/*number of domestic arrests*/
data chicago_domestic_arrests;
set freq_domestic_arrest;
number_of_domestic_arrests = count;
drop count percent;
run;

proc sort data = chicago_domestic;
by date_n;
proc sort data = chicago_domestic_arrests;
by date_n;
data domestics;
merge chicago_domestic chicago_domestic_arrests;
by date_n;
drop domestic arrest;
arrest_ratio = (number_of_domestic_arrests/number_of_domestics) * 100;
run;

proc ttest data = domestics side=l;
class temperature;
var arrest_ratio;
run;


/**********************************************************************************/
data chicago_rates_temp;
set crime_arrest_rates;
keep temp arrest_rate;
run;

proc ttest data = chicago_rates_temp side= l;
class temp;
var arrest_rate;
run;

proc freq data = chicago_crimes order = freq;
tables temp*Primary_type*arrest / chisq relrisk;
run;





