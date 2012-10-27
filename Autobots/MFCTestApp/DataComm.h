#pragma once

// DataComm command target

class DataComm : public CSocket
{
public:
	DataComm();
	virtual ~DataComm();

	bool SendData(char* s, double data);
	bool SendData(char* s, int data);
	bool SendData(char* s, char* data);
private:
	bool DoSendData(char* data);
};


