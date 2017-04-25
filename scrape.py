
# to run from command line
# 	$pip3 install requests (required download, move files to current directory)
# 	$pip install pdfminer (requires download, move file to current directory)
# 	$python3
# 	>>>import scrape
# 	>>>scrape.scrape()

from socket import timeout
import logging
import requests
import subprocess
import csv


def load_sensors(filename):
	with open(filename, 'r') as f:
		reader = csv.reader(f)
		l=list(reader)
		return l


def save(url):
	response = requests.get(url)
	with open('tmp.pdf', 'wb') as f:
		f.write(response.content)

def matchcondition(the_string):
	return not any(c.isalpha() for c in the_string) and "." in the_string and "-" not in the_string

def scrape():
	#clear output csv
	filename = "output.csv"
	f = open(filename, "w+")
	f.close()

	sensor_list=load_sensors('speed_sensors.csv')
	sensor_list=sensor_list[1::2] #deals with duplicates

	'''
	pass this a list of triples [[sensor_name, tmp, siteno],...
	'''

	for sensor in sensor_list: 
		sensor_name=sensor[0]
		print(sensor_name)
		tmp=sensor[1]
		siteno=sensor[2]
		for year in range(2005,2010):
			print(year)
			for month in range(1,12):
				for day in range (1,31):
					mean="none"
					median="none"
					mean_pos="none"
					median_pos="none"
					mean_neg="none"
					median_neg="none"
					sensor_name.replace(" ", "%20")
					year=str(year)
					month=str(month)
					if len(month)<2:
						month="0"+month
					day=str(day)
					if len(day)<2:
						day="0"+day
					url="http://www.th.gov.bc.ca/trafficData/TRADAS/reports/AllYears/" + year + "/" + month + "/DS01/DS01%20-%20Site%20" + sensor_name +"%20-%20" + tmp + "%20-%20N%20on%20" + month + "-" + day + "-" + year +".pdf"
					try:
						response = requests.get(url, timeout=1) #try to get url, of not (connection error) print error, continue
						if response.status_code==200: #if website is valid 
							save(url) #calls save function defined above

							try: 
								out=subprocess.check_output(['pdf2txt.py','tmp.pdf']) #obtain text (subprocess calls to command liner)
								string=str(out) 
								words=string.split("\\n") #split based on newline
								tardunos_generator=(x for x in words if matchcondition(x)) #used in finding mean/median from soup

								#identify the first float in stream (mean) and the second (median)
								try: 	
									mean=next(tardunos_generator)
								except StopIteration:
									pass
								try:
									median=next(tardunos_generator)
								except StopIteration:
									pass									
								try:
									trash=[next(tardunos_generator) for i in range(7)]
									mean_pos=next(tardunos_generator)
									median_pos=next(tardunos_generator)
								except StopIteration:
									pass									
								try:
									trash=[next(tardunos_generator) for i in range(7)]
									mean_neg=next(tardunos_generator)
									median_neg=next(tardunos_generator)
								except StopIteration:
									pass
								with open("output.csv", "a") as fp:
									wr = csv.writer(fp, dialect='excel')
									wr.writerow([month,day,year,sensor_name,siteno,mean,median,mean_pos,median_pos,mean_neg,median_neg])

							except subprocess.CalledProcessError:
								print("")
								print("error")
								print(month, "-", day, year)

								with open("output.csv", "a") as fp:
									wr = csv.writer(fp, dialect='excel')
									wr.writerow([month,day,year,sensor_name,siteno,mean,median,mean_pos,median_pos,mean_pos,median_neg])
						else:
							pass
					except requests.exceptions.ConnectionError as e:
						print (e)


