#pragma once

#include <mutex>

#include "luawrapper/AudioLuaContext.h"
#include "model/ProcessingContext.h"
#include "messaging.h"
#include "micromsg/readerwriterqueue.h"

using AudioLuaContextPtr = std::shared_ptr<AudioLuaContext>;

struct AudioMidiEvent {
	int offset;
	int status;
	int data1;
	int data2;
};

class AudioController {
private:
	AudioLuaContextPtr _lua;
	ProcessingContext _processingContext;
	Node* _node = nullptr;
	TimeInfo* _timeInfo;
	std::mutex _lock;
	moodycamel::ReaderWriterQueue<AudioMidiEvent> _midiQueue { 256 };
	double _sampleRate;

public:
	AudioController(TimeInfo* timeInfo, double sampleRate): _timeInfo(timeInfo), _sampleRate(sampleRate) {}
	~AudioController() {}

	std::mutex* getLock() { return &_lock; }

	void setNode(Node* node);

	void setAudioSettings(const AudioSettings& settings);

	void fetchState(const FetchStateRequest& req, FetchStateResponse& state);

	bool getSram(SystemIndex idx, DataBuffer<char>* target);
	bool enqueueMidi(int offset, int status, int data1, int data2);

	void onMenu(SystemIndex idx, std::vector<Menu*>& menus);

	void process(float** outputs, size_t frameCount);

	AudioLuaContextPtr& getLuaContext() { return _lua; }
};
