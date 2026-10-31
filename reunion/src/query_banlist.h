#pragma once

#include <unordered_set>
#include <vector>

struct ban_t
{
	uint32_t ip;
	uint32_t end;
	int pps;
};

class CQueryBanlist
{
public:
	void addBan(uint32_t ip, uint32_t time, int pps);
	void addBan(uint32_t ip, uint32_t time);
	bool removeBan(uint32_t ip);
	bool isBanned(uint32_t ip) const;
	void removeExpired(uint32_t realtime);
	void print();

private:
	std::vector<ban_t> m_bans;
	mutable std::unordered_set<uint32_t> m_bannedIPs; // O(1) lookup cache, rebuilt on mutation
	bool m_dirtySet = true;

	void rebuildIPSet() const;
};
