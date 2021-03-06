##################################################
## This script was used to read the data exported
## for the Quantified Self (QS) report
##################################################
##################################################
## Author: Abhisek Gautam
## Version: 1.0
## Email: abhisekgautam302@gmail.com
## Status: Development
## Date: 9th April 2020
##################################################

# Load necessary Libraries
library(jsonlite)
library(lubridate)
library(zoo)
library(dplyr)
library(plyr)
library(ggplot2)
library(ggmap)
library(readxl)
library(anytime)
library(raster)

setwd("Datasets")
# Get the system's time from Location data
system.time(x <- fromJSON("Abhisek/Location_History.json"))
system.time(y <- fromJSON("Ganesh/LocationHistory.json"))
system.time(z <- fromJSON("Vincent/LocationHistory.json"))

setwd("..")

# extracting the locations dataframe
loc = x$locations
loc_y= y$locations
loc_z= z$locations

# Convert the time column from posix milliseconds into a readable time scale
loc$time = as.POSIXct(as.numeric(x$locations$timestampMs)/1000, origin = "1970-01-01")
loc_y$time = as.POSIXct(as.numeric(y$locations$timestampMs)/1000, origin = "1970-01-01")
loc_z$time = as.POSIXct(as.numeric(z$locations$timestampMs)/1000, origin = "1970-01-01")


# Convert the longitude and latitude from E7 to GPS coordinates
loc$lat = loc$latitudeE7 / 1e7
loc$lon = loc$longitudeE7 / 1e7

loc_y$lat = loc_y$latitudeE7 / 1e7
loc_y$lon = loc_y$longitudeE7 / 1e7

loc_z$lat = loc_z$latitudeE7 / 1e7
loc_z$lon = loc_z$longitudeE7 / 1e7


#Filter date according to project day
rng <- interval('2019-08-04', '2019-09-14')          #desired range
loc_x <- loc[loc$time %within% rng,]
loc_y <- loc_y[loc_y$time %within% rng,]
loc_z <- loc_z[loc_z$time %within% rng,]


##############################
# For Map- Location History
##############################

# Map Key hidden, add your own
register_google(key = "map_key", write= TRUE)

# Initialize the Map's type and center
myLocation<-"SYDNEY"
sources<-c("stamen","google","osm","cloudmade")
stamenmaps = c("terrain", "toner", "watercolor")
googlemaps = c("roadmap", "terrain", "satellite", "hybrid")
i=2   #as an example 
k=1
myMap <- get_map(location=c(151.200223, -33.890353), source=sources[[i]], maptype=googlemaps[[k]], crop=FALSE,zoom= 10)


# Plot the coordinates to the loaded map above
ggmap(myMap) + geom_point(data = loc, aes(x = lon, y = lat), alpha = 0.3, color = "red") + 
  geom_point(data = loc_y, aes(x = lon, y = lat), alpha = 0.3, color = "blue") + 
  geom_point(data = loc_z, aes(x = lon, y = lat), alpha = 0.3, color = "green") + 
  theme(legend.position = "right") + 
  labs(
    x = "Longitude", 
    y = "Latitude", 
    title = "Visualization of visited places in Sydney")

## Calculate the distance traveled using each vector positions
shift.vec <- function(vec, shift){
  if (length(vec) <= abs(shift)){
    rep(NA ,length(vec))
  } else {
    if (shift >= 0) {
      c(rep(NA, shift), vec[1:(length(vec) - shift)]) }
    else {
      c(vec[(abs(shift) + 1):length(vec)], rep(NA, abs(shift)))
    }
  }
}

loc_x$lat.p1 <- shift.vec(loc_x$lat, -1)
loc_x$lon.p1 <- shift.vec(loc_x$lon, -1)

# Calculating distances between points (in metres) with the function pointDistance from the 'raster' package.
loc_x$dist.to.prev <- apply(loc_x, 1, FUN = function(row) {
  pointDistance(c(as.numeric(as.character(row["lat.p1"])),
                  as.numeric(as.character(row["lon.p1"]))),
                c(as.numeric(as.character(row["lat"])), as.numeric(as.character(row["lon"]))),
                lonlat = T) # Parameter 'lonlat' has to be TRUE!
})

# Get date and time of the locations
loc_x$Date <- as.Date(loc_x$time)
aggregate(loc_x$dist.to.prev, by=list(loc_x$Date), sum, na.rm=TRUE)


# Get the distance per day covered
distance_p_day <- aggregate(loc_x$dist.to.prev,
                            by = list(month_year = as.factor(loc_x$month_year)), FUN = sum)

dist_x <- aggregate(loc_x$dist.to.prev, by=list(loc_x$Date), sum, na.rm=TRUE)

loc_x$lat.p1 <- shift.vec(loc_x$lat, -1)
loc_x$lon.p1 <- shift.vec(loc_x$lon, -1)


##############################
# For Steps Count
##############################

# Get steps data from each person's dataset
steps_x <- read.csv("Datasets/Abhisek/Daily Summaries.csv")
steps_y <-read.csv("Datasets/Ganesh/Ganesh steps final.csv")
steps_z <- read.csv("Datasets/Vincent/Vincent_steps_final_file.csv")

# Convert the date to date format and add them to the above data
steps_x$Date <- as.Date(steps_x$Date, "%d/%m/%y")
steps_y$Date <- as.Date(steps_y$Date, "%d/%m/%y")
steps_z$Date <- as.Date(steps_z$Date, "%d/%m/%y")

# compute weekly aggregates by grouping
steps_sum_week_x<- steps_x %>% group_by(week = cut(Date, "week", start.on.monday = FALSE))
steps_sum_week_x<- aggregate(steps_sum_week_x$Step.count, by=list(Category=steps_sum_week_x$week), FUN=sum,  na.rm=T)
colnames(steps_sum_week_x) <- c('WeekID', 'Steps_x')
  
steps_sum_week_y <- steps_y %>% group_by(week = cut(Date, "week", start.on.monday = FALSE))
steps_sum_week_y<- aggregate(steps_sum_week_y$Step.count, by=list(Category=steps_sum_week_y$week), FUN=sum,  na.rm=T)
colnames(steps_sum_week_y) <- c('WeekID', 'Steps_y')

steps_sum_week_z <- steps_z %>% group_by(week = cut(Date, "week", start.on.monday = FALSE))
steps_sum_week_z <-aggregate(steps_sum_week_z$Step.count, by=list(Category=steps_sum_week_z$week), FUN=sum,  na.rm=T)
colnames(steps_sum_week_z) <- c('WeekID', 'Steps_z')

# Combine all steps data and Compare Steps by weeks
StepsCompare <- cbind(steps_sum_week_x$Steps_x, steps_sum_week_y$Steps_y, steps_sum_week_z$Steps_z)
StepsCompare <- t(StepsCompare)
colnames(StepsCompare) <- c("Week1", "Week2", "Week3", "Week4", "Week5", "Week6")
rownames(StepsCompare) <- c("Person1", "Person2", "Person3")


## plot datafraome directly with three colours
colours <- c("red", "blue", "green")

p <- barplot(StepsCompare, main="Steps Count comparision by Week",
        xlab="Week Numbers", col=colours, ylab="Number of Steps", xlim= c(0,30) , legend= rownames(StepsCompare),
        beside=TRUE)


# Combine Steps data
stepsCombine <- 0
stepsCombine <- steps_x$Date 
stepsCombine <- cbind.data.frame(stepsCombine, steps_x$Step.count, steps_y$Step.count, steps_z$Step.count)
colnames(stepsCombine) <- c("Date", "steps_x", "steps_y", "steps_z")

ggplot(stepsCombine, aes(Date)) + 
  geom_point(aes(y = steps_x, colour = "Person1")) + 
  geom_smooth(aes(y = steps_x, colour = "Person1"), se=F)+
  geom_point(aes(y = steps_y, colour = "Person2"))+ 
  geom_smooth(aes(y = steps_y, colour = "Person2"), se=F)+ 
  geom_point(aes(y = steps_z, colour = "Person3"))+ 
  geom_smooth(aes(y = steps_z, colour = "Person3"), se=F)+ 
  ylab("Steps")

##############################
# Mood Data
#
#
# Mood data was extracted from Azure's Face Recognition API
##############################


# Read Mood's CSVs
mood_x <- read_excel("Datasets/Abhisek/emo_abhisek.xlsx")
mood_y <-read_excel("Datasets/Ganesh/emo_ganesh.xlsx")
mood_z <- read_excel("Datasets/Vincent/emo_vincent.xlsx")

mood_x$Date <- as.Date(mood_x$Date, "%Y%m%d")
mood_y$Date <- as.Date(mood_y$Date, "%Y%m%d")
mood_z$Date <- as.Date(mood_z$Date, "%Y%m%d")


# Create Scatte plots to see Moods for each person
ggplot(mood_x, aes(Date)) + 
  geom_point(aes(y = Anger, colour = "Anger")) + 
  geom_point(aes(y = Contempt, colour = "Contempt"))+ 
  geom_point(aes(y = Disgust, colour = "Disgust"))+ 
  geom_point(aes(y = Fear, colour = "Fear"))+ 
  geom_point(aes(y = Happiness, colour = "Happiness"))+ 
  geom_point(aes(y = Neutral, colour = "Neutral"))+ 
  geom_point(aes(y = Sadness, colour = "Sadness"))+
  geom_point(aes(y = Surprise, colour = "Surprise"))+
  ylab("Mood Percentage")

ggplot(mood_y, aes(Date)) + 
  geom_point(aes(y = Anger, colour = "Anger")) + 
  geom_point(aes(y = Contempt, colour = "Contempt"))+ 
  geom_point(aes(y = Disgust, colour = "Disgust"))+ 
  geom_point(aes(y = Fear, colour = "Fear"))+ 
  geom_point(aes(y = Happiness, colour = "Happiness"))+ 
  geom_point(aes(y = Neutral, colour = "Neutral"))+ 
  geom_point(aes(y = Sadness, colour = "Sadness"))+
  geom_point(aes(y = Surprise, colour = "Surprise"))+
  ylab("Mood Percentage")

ggplot(mood_z, aes(Date)) + 
  geom_point(aes(y = Anger, colour = "Anger")) + 
  geom_point(aes(y = Contempt, colour = "Contempt"))+ 
  geom_point(aes(y = Disgust, colour = "Disgust"))+ 
  geom_point(aes(y = Fear, colour = "Fear"))+ 
  geom_point(aes(y = Happiness, colour = "Happiness"))+ 
  geom_point(aes(y = Neutral, colour = "Neutral"))+ 
  geom_point(aes(y = Sadness, colour = "Sadness"))+
  geom_point(aes(y = Surprise, colour = "Surprise"))+
  ylab("Mood Percentage")


##############################
# Facebook's Messages data
#
##############################

#resolve conflict and select preferred select method from dplyr
# Instantiate object
system.time(all_messages <- fromJSON("Datasets/inbox/sample/message_1.json")[["messages"]])
all_messages$time = as.POSIXct(as.numeric(all_messages$timestamp_ms)/1000, origin = "1970-01-01")
all_messages <- all_messages %>% dplyr::select(sender_name, time)
all_messages <- all_messages[FALSE, ]


for(i in list.dirs(path = "Datasets/inbox", full.names = TRUE, recursive = FALSE)){
  system.time(message_json <- fromJSON(paste(i, "/message_1.json", sep=''))[["messages"]])
  message_json$time = as.POSIXct(as.numeric(message_json$timestamp_ms)/1000, origin = "1970-01-01")
  all_messages <- rbind(all_messages, message_json %>% dplyr::select(sender_name, time))
}

message_json <- message_json[FALSE, ]
all_messages <- cbind(all_messages, count=1)


all_messages$Date <- format(as.POSIXct(all_messages$time,format='%Y-%m-%s %H:%M:%S'),format='%Y-%m-%d')



##############################
# Get Rainfall's data
##############################

rainfall_data <- read.csv("Datasets/Weather/Rainfall_Data.csv")

rainfall_data$Date <- paste(rainfall_data$Year, rainfall_data$Month, rainfall_data$Day, sep="/")
rainfall_data$Date <- as.Date(rainfall_data$Date, "%Y/%m/%d")

rainfall_data1 <- sqldf("select * from rainfall_data where Date >= '2018-08-04' and Date <= '2018-09-14' ")

rainfall_data <- rainfall_data %>% filter(
    Date >= as.Date('2019/08/04', "%Y/%m/%d"), Date <= as.Date('2019/09/14', "%Y/%m/%d")
  )


# Plot Rainfall amounts
ggplot(rainfall_data, aes(Date)) + 
  geom_bar(stat="identity", aes(y = Rainfall.amount..millimetres., fill = Rainfall.amount..millimetres.)) + 
  ylab("Rainfall in mm")+
  scale_fill_continuous(name = "Rainfall")

####################
# Group Analysis
####################

#Aggregate all Data
mood_x <- sqldf ("select DATE, avg(Anger) as Anger, avg(Contempt) as Contempt, avg(Disgust) as Disgust, 
avg(Fear) as Fear, avg(Happiness) as Happiness, avg(Neutral) as Neutral, avg(Sadness) as Sadness,
avg(Surprise) as Surprise from mood_x group by Date")

mood_y <- sqldf ("select DATE, avg(Anger) as Anger, avg(Contempt) as Contempt, avg(Disgust) as Disgust, 
avg(Fear) as Fear, avg(Happiness) as Happiness, avg(Neutral) as Neutral, avg(Sadness) as Sadness,
avg(Surprise) as Surprise from mood_y group by Date")

mood_z <- sqldf ("select DATE, avg(Anger) as Anger, avg(Contempt) as Contempt, avg(Disgust) as Disgust, 
avg(Fear) as Fear, avg(Happiness) as Happiness, avg(Neutral) as Neutral, avg(Sadness) as Sadness,
avg(Surprise) as Surprise from mood_z group by Date")

agg_x <- sqldf("select a.Date, \"Step.Count\", Anger, Contempt, Disgust,
Fear, Happiness, Neutral, Sadness, Surprise, c.'Rainfall.amount..millimetres.' as Rainfall from steps_x a left join
               mood_x b on a.Date = b.Date
               left join rainfall_data c on c.Date = a.Date")

agg_y <- sqldf("select a.Date, \"Step.Count\", Anger, Contempt, Disgust,
Fear, Happiness, Neutral, Sadness, Surprise, c.'Rainfall.amount..millimetres.' as Rainfall  from steps_y a left join
               mood_y b on a.Date = b.Date
               left join rainfall_data c on c.Date = a.Date")

agg_z <- sqldf("select a.Date, \"Step.Count\", Anger, Contempt, Disgust,
Fear, Happiness, Neutral, Sadness, Surprise, c.'Rainfall.amount..millimetres.' as Rainfall  from steps_z a left join
               mood_z b on a.Date = b.Date
               left join rainfall_data c on c.Date = a.Date")


# For specific date- 27 August

#For Map Analysis 27 August 2019
#filtering date according to project day
rng <- interval('2019-08-27', '2019-08-28')          #desired range
loc_x <- loc[loc$time %within% rng,]
loc_y <- loc_y[loc_y$time %within% rng,]
loc_z <- loc_z[loc_z$time %within% rng,]



#For Map Analysis 27 August 2019

register_google(key = "AIzaSyBv_kWY92DpakNzS_8bprrUmxPbgZOZlZA", write= TRUE)

myLocation<-"SYDNEY"
sources<-c("stamen","google","osm","cloudmade")
stamenmaps = c("terrain", "toner", "watercolor")
googlemaps = c("roadmap", "terrain", "satellite", "hybrid")
i=2   #as an example 
k=1
myMap <- get_map(location=c(151.199657, -33.882084), source=sources[[i]], maptype=googlemaps[[k]], crop=FALSE,zoom= 15)

# Plot into myMap
ggmap(myMap) + geom_point(data = loc_x, aes(x = lon, y = lat), alpha = 0.3, color = "red") + 
  geom_point(data = loc_y, aes(x = lon, y = lat), alpha = 0.3, color = "blue") + 
  geom_point(data = loc_z, aes(x = lon, y = lat), alpha = 0.3, color = "green") + 
  theme(legend.position = "right") + 
  labs(
    x = "Longitude", 
    y = "Latitude", 
    title = "Visualization on 27th August 2019",
    caption = "\nA simple plot showing GPS Data of 3 members, highlighted by red, green and blue respectively.")

#Count of GPS data for 27th Aug 2019
cbind(Member1 =count(loc_x), Member2 = count(loc_y), Member3 =count(loc_z))


# Plot comparision plots for the report for each member
step_happiness_x <- cbind.data.frame(agg_x$Step.count, agg_x$Happiness)
colnames(step_happiness_x) <- c("Step.count", "Happiness")

md <- round(step_happiness_x$Happiness, digits = 1)
md[md==0] <- NA 
step_happiness_x$cleaned <- md

ggplot(step_happiness_x, aes(Step.count)) + 
  geom_point(stat="identity", aes(y = cleaned)) + 
  geom_smooth(aes(y = cleaned))+
  ylab("Happiness")+
  labs(title = "Person 1")+
  xlab("Number of Steps")


step_happiness_y <- cbind.data.frame(agg_y$Step.count, agg_y$Happiness)
colnames(step_happiness_y) <- c("Step.count", "Happiness")

md <- round(step_happiness_y$Happiness, digits = 2)
md[md==0] <- NA 
step_happiness_y$cleaned <- md

ggplot(step_happiness_y, aes(Step.count)) + 
  geom_point(stat="identity", aes(y = cleaned,)) + 
  geom_smooth(aes(y = cleaned))+
  ylab("Happiness")+
  xlab("Number of Steps")+
  labs(title = "Person 2")+
  scale_color_manual(values=c("Blue"))


step_happiness_z <- cbind.data.frame(agg_z$Step.count, agg_z$Happiness)
colnames(step_happiness_z) <- c("Step.count", "Happiness")

md <- round(step_happiness_z$Happiness, digits = 3)
md[md==0] <- NA 
step_happiness_z$cleaned <- md

ggplot(step_happiness_z, aes(Step.count)) + 
  geom_point(stat="identity", aes(y = cleaned)) + 
  geom_smooth(aes(y = cleaned))+
  ylab("Happiness")+
  xlab("Number of Steps")+
  labs(title = "Person 3")+
  scale_color_manual(values=c("Green"))


#Rainfall and Steps Data
ggplot(agg_x, aes(Date)) + 
  geom_bar(stat= "identity", aes(y = Step.count)) + 
  geom_line(aes(y = Rainfall * 314, colour = "Rainfall"))+
  scale_y_continuous(sec.axis = sec_axis(~./314, name = "Rainfall"))+
labs(title = "Person 1")+
  ylab("Steps")
  
  ggplot(agg_y, aes(Date)) + 
    geom_bar(stat= "identity", aes(y = Step.count)) + 
    geom_line(aes(y = Rainfall * 314, colour = "Rainfall"))+
    scale_y_continuous(sec.axis = sec_axis(~./314, name = "Rainfall"))+
    labs(title = "Person 2")+
    ylab("Steps")
  
  ggplot(agg_z, aes(Date)) + 
    geom_bar(stat= "identity", aes(y = Step.count)) + 
    geom_line(aes(y = Rainfall * 314, colour = "Rainfall"))+
    scale_y_continuous(sec.axis = sec_axis(~./314, name = "Rainfall"))+
    labs(title = "Person 3")+
    ylab("Steps")

  
# Rainfall vs Messages
msg_summary <- sqldf("select sender_name, Date, sum(count) as number_of_messages from all_messages
                     where sender_name= 'Abhisek Gautam' group by Date")

msg_summary$Date <- as.Date(msg_summary$Date, "%Y-%m-%d")

individualSummary <- sqldf("select * from msg_summary t1
                     inner join agg_x t2 on
                     t1.Date = t2.Date")
  
dat.summary$Time <- anytime(as.factor(dat.summary$Time))
  
ggplot(individualSummary, aes(Date)) + 
  geom_bar(stat= "identity", aes(y = number_of_messages)) + 
  geom_line(aes(y = Rainfall * 10, colour = "Rainfall"))+
  scale_y_continuous(sec.axis = sec_axis(~./10, name = "Rainfall"))+
  labs(title = "Individual Data- Messages and Rainfall Comparision")+
  ylab("Messages")


#Steps vs Messages
ggplot(individualSummary, aes(Step.count)) + 
  geom_point(aes(y = number_of_messages, colour = "Person1")) + 
  geom_smooth(aes(y = number_of_messages), se=F)+
  labs(title= "Number of Messages Vs Steps", y= "Number of Messages", x ="Steps")


#Steps via day
individualSummary$dayOfWeek <- weekdays(individualSummary$Date)

data <- sqldf("select dayOfWeek, sum(\"Step.count\") no_of_steps from individualSummary group by dayOfWeek")

data$dayOfWeek <- factor(data$dayOfWeek, levels= c("Sunday", "Monday", 
                                         "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"))

data[order(data$dayOfWeek), ]

# Plot data
ggplot(data = data, aes(x = dayOfWeek, 
                           y = no_of_steps)) + 
  geom_bar(stat="identity", aes()) +
  xlab('Weekday') +
  ylab('Number of Steps') +
  labs(title= "Number of Steps ~ Weekday Aggregate")
  
  





  

