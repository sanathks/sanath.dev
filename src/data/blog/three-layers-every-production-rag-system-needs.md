---
author: Sanath Samarasinghe
pubDatetime: 2026-02-13T00:00:00Z
modDatetime: 2026-02-15T23:00:00Z
title: The Three Layers Every Production RAG System Needs
featured: true
draft: false
tags:
  - ai
  - rag
  - langchain
  - opensource
  - development
description: Document parsing, hybrid search, and orchestration - the three layers that separate toy RAG demos from production systems.
---

"Context windows are huge now, do we even need RAG?"

Yes. Even with million-token windows, stuffing everything in is expensive, slow, and less accurate than giving models exactly what they need.

But most RAG tutorials skip the hard parts. Here's what actually matters.

## The Three Layers

Every production RAG system needs:

1. **Document parsing** that doesn't destroy structure
2. **Hybrid search** combining keywords and semantics
3. **Orchestration** that handles the messy reality

![Production RAG Architecture](/images/rag-architecture.svg)

Most demos skip layer one entirely and oversimplify the rest. That's why they fail on real documents.

## Layer 1: Document Parsing with Docling

This is where most RAG systems quietly fail. Real documents have tables, multi-column layouts, images, code blocks, and formulas. A naive PDF-to-text converter mangles all of it.

Docling is an open-source parser that actually handles this. Feed it a complex PDF and it preserves structure - tables stay as tables, columns maintain reading order, code blocks stay intact.

```bash
pip install langchain-docling
```

```python
from langchain_docling.loader import DoclingLoader

loader = DoclingLoader(file_path="document.pdf")
docs = loader.load()

for doc in docs:
    print(doc.page_content)
```

Docling supports PDF, DOCX, PPTX, XLSX, HTML, images with OCR, and even audio files with speech recognition. The LangChain integration handles chunking automatically.

Garbage in, garbage out. Fix your parsing first.

## Layer 2: Hybrid Search with OpenSearch

Pure vector search misses exact matches ("GDPR compliance" might not surface documents that literally say "GDPR compliance"). Pure keyword search misses semantic relationships. You need both.

OpenSearch handles this well - vector similarity and BM25 keyword search in a single query, results ranked by a weighted combination.

```bash
pip install opensearch-py langchain-community langchain-openai
```

```python
from langchain_community.vectorstores import OpenSearchVectorSearch
from langchain_openai import OpenAIEmbeddings

embeddings = OpenAIEmbeddings()

# Index your documents
docsearch = OpenSearchVectorSearch.from_documents(
    docs,
    embeddings,
    opensearch_url="http://localhost:9200"
)

# Search with hybrid scoring
results = docsearch.similarity_search(
    "What are the compliance requirements?",
    k=5
)
```

Other options like Weaviate and Pinecone offer similar hybrid capabilities. The key insight: retrieval quality directly determines response quality. Spend time tuning your search before optimizing prompts.

## Layer 3: Orchestration with LangChain

A real RAG pipeline isn't just "search and generate." You need query rewriting, re-ranking, source attribution, fallback handling, and conversation memory.

```python
from langchain.chains import RetrievalQA
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o")

qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=docsearch.as_retriever(search_kwargs={"k": 5}),
    return_source_documents=True
)

result = qa_chain.invoke({"query": "What are the main compliance requirements?"})
print(result["result"])
print(result["source_documents"])
```

For more complex pipelines, use LCEL (LangChain Expression Language) to compose retrieval, reranking, and generation steps with full control over the flow.

## The Bottom Line

Three layers: parsing, search, orchestration. Most failures trace back to layer one - bad document parsing that corrupts your knowledge base from the start.

Get the parsing right with Docling. Use hybrid search, not just vectors. Build orchestration with LangChain that lets you iterate. Everything else is optimization.

ciao
