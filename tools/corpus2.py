import pickle, collections
S = r'C:\Users\Fluent\AppData\Local\Temp\claude\64d96de68a049de7\e3f69e87-1127-44ee-8609-cdd731c4a651\scratchpad'
corpus = pickle.load(open(S + r'\corpus.pkl', 'rb'))
items = sorted(corpus.items(), key=lambda kv: (-len(kv[1]), kv[1][0]))
ids = {}
with open(S + r'\corpus.txt', 'w', encoding='utf-8') as f:
    for n, (t, locs) in enumerate(items):
        ids[n] = t
        recs = sorted({x[0].split('/')[-1][:-4] for x in locs})
        f.write('%d|%d|%s|%s\n' % (n, len(locs), t.replace('\n', ' / '), ','.join(recs[:3])))
pickle.dump(items, open(S + r'\corpus_items.pkl', 'wb'))
print(len(items))
big = [len(l) for t, l in items]
print(sum(1 for b in big if b >= 3), sum(1 for b in big if b >= 4))
