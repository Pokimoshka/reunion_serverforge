#pragma once

#include <set>
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
	mutable std::set<uint32_t> m_bannedIPs; // O(log n) lookup cache. Uses _Rb_tree (GLIBCXX_3.4),
	                                        // NOT _Prime_rehash_policy (GLIBCXX_3.4.18), to keep ABI compatibility.
	mutable bool m_dirtySet = true;

	void rebuildIPSet() const;
};
