package store

import (
	"context"
	"sort"
	"sync"
)

type MemoryAdapter struct {
	mu   sync.RWMutex
	data map[string]map[string][]byte
}

func NewMemoryAdapter() *MemoryAdapter {
	return &MemoryAdapter{data: map[string]map[string][]byte{}}
}

func (m *MemoryAdapter) Kind() string { return "memory" }

func (m *MemoryAdapter) Ping(context.Context) error { return nil }

func (m *MemoryAdapter) UpsertRaw(_ context.Context, collection, id string, payload []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.data[collection]; !ok {
		m.data[collection] = map[string][]byte{}
	}
	cloned := make([]byte, len(payload))
	copy(cloned, payload)
	m.data[collection][id] = cloned
	return nil
}

func (m *MemoryAdapter) GetRaw(_ context.Context, collection, id string) ([]byte, bool, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	items, ok := m.data[collection]
	if !ok {
		return nil, false, nil
	}
	payload, ok := items[id]
	if !ok {
		return nil, false, nil
	}
	cloned := make([]byte, len(payload))
	copy(cloned, payload)
	return cloned, true, nil
}

func (m *MemoryAdapter) Delete(_ context.Context, collection, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.data[collection]; ok {
		delete(m.data[collection], id)
	}
	return nil
}

func (m *MemoryAdapter) ListRaw(_ context.Context, collection string) ([][]byte, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	items, ok := m.data[collection]
	if !ok {
		return [][]byte{}, nil
	}
	keys := make([]string, 0, len(items))
	for key := range items {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	result := make([][]byte, 0, len(items))
	for _, key := range keys {
		payload := items[key]
		cloned := make([]byte, len(payload))
		copy(cloned, payload)
		result = append(result, cloned)
	}
	return result, nil
}

func (m *MemoryAdapter) Close() error { return nil }
