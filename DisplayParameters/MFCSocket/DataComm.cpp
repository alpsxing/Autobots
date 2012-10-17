// DataComm.cpp : implementation file
//

#include "stdafx.h"
#include "MFCSocket.h"
#include "DataComm.h"
#include "afxwin.h"
#include <math.h>
#include <stdlib.h>

// DataComm

DataComm::DataComm()
{
}

DataComm::~DataComm()
{
}

bool DataComm::SendData(char* s, double data)
{
	char msg[1024];
	char cd[36];
	_gcvt_s(cd, data, 32); 
	int len = strlen(s);
	len = len+1;
	len = len + strlen(cd);
	if(len > 1024)
	{
		CString errmsg;
		errmsg.Format(_T("Data length > 1024 : %s:%s"), s, cd);
		AfxMessageBox(errmsg);
		return false;
	}
	strcpy_s(msg, s);
	strcat_s(msg, ":");
	strcat_s(msg, cd);
	return DoSendData(msg);
}

bool DataComm::SendData(char* s, int data)
{
	char msg[1024];
	char cd[36];
	_itoa_s(data, cd, 10); 
	int len = strlen(s);
	len = len+1;
	len = len + strlen(cd);
	if(len > 1024)
	{
		CString errmsg;
		errmsg.Format(_T("Data length > 1024 : %s:%s"), s, cd);
		AfxMessageBox(errmsg);
		return false;
	}
	strcpy_s(msg, s);
	strcat_s(msg, ":");
	strcat_s(msg, cd);
	return DoSendData(msg);
}

bool DataComm::SendData(char* s, char* data)
{
	char msg[1024];
	int len = strlen(s);
	len = len+1;
	len = len + strlen(data);
	if(len > 1024)
	{
		CString errmsg;
		errmsg.Format(_T("Data length > 1024 : %s:%s"), s, data);
		AfxMessageBox(errmsg);
		return false;
	}
	strcpy_s(msg, s);
	strcat_s(msg, ":");
	strcat_s(msg, data);
	return DoSendData(msg);
}

bool DataComm::DoSendData(char* data)
{
	AfxSocketInit();
	CSocket sock;
	if(!sock.Create())
	{
		CString errmsg;
		errmsg.Format(_T("Socket creation faild: %d"), sock.GetLastError());
		AfxMessageBox(errmsg);
		return false;
	}
	CString ip;
	ip.Format(_T("127.0.0.1"));
	if(sock.Connect(ip, 3579))
	{
		sock.Send(data, strlen(data));
	}
	else
	{
		CString errmsg;
		errmsg.Format(_T("Socket connection faild: %d"), sock.GetLastError());
		AfxMessageBox(errmsg);
		return false;
	}
	sock.Close();

	return true;
}