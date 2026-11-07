/* Word LZ encoder matching the pinned upstream page schedule. Original project
 * implementation; no game data. Exported for optional Python acceleration. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#define API __declspec(dllexport)
#else
#define API
#endif
API int practice_compress_tail(const uint16_t *w,int n,uint8_t *out,int cap,int maxmatch,int blocklimit,int prefix,int pagelimit,int startword){
 int *prev=malloc(sizeof(int)*n),*head=malloc(sizeof(int)*65536);
 if(!prev||!head){free(prev);free(head);return -1;}
 for(int a=0;a<65536;a++)head[a]=-1;
 for(int j=(startword>2047?startword-2047:0);j<startword;j++){prev[j]=head[w[j]];head[w[j]]=j;}
 int i=startword,p=0,count=0,start=0,bout=0,ext=0,blocks=0,pageout=0;unsigned control=0;
 #define PUT(v) do{if(p+2>cap){free(prev);free(head);return -2;}out[p++]=(v)&255;out[p++]=((v)>>8)&255;}while(0)
 while(i<n){
  if(count==0){start=p;PUT(0);control=0;bout=0;}
  int max=blocklimit-bout-(15-count);if(max<1)max=1;
  if(max>maxmatch)max=maxmatch;if(max>n-i)max=n-i;
  if(ext>=4&&max>31)max=31;if(i<prefix&&max>1)max=1;
  if(pagelimit){int reserve=(2048-p%2048+1)/2+15;int allowance=pagelimit-pageout-reserve;if(allowance<1)allowance=1;if(max>allowance)max=allowance;}
  int best=0,dist=0;
  if(i>=16){
   for(int q=head[w[i]];q>=0&&i-q<=2047;q=prev[q]){
    if(best&&w[i+best]!=w[q+best])continue;
    int l=1;while(l<max&&w[i+l]==w[q+l])l++;
    if(l>best){best=l;dist=i-q;if(l==max)break;}
   }
  }
  int used=1;
  if(best>=2||(best==1&&ext<4)){
   used=best;control|=1u<<(15-count);
   if(best>31||ext<4){PUT(dist);PUT(best);ext++;}else PUT((best<<11)|dist);
  }else PUT(w[i]);
  for(int j=i;j<i+used;j++){prev[j]=head[w[j]];head[w[j]]=j;}
  i+=used;bout+=used;pageout+=used;count++;
  if(count==16){out[start]=control&255;out[start+1]=control>>8;count=0;blocks++;
   if(blocks==60){if(p%2048||ext!=4){free(prev);free(head);return -3;}blocks=ext=pageout=0;}
  }
 }
 if(count==0){start=p;PUT(0);control=0;}
 control|=1u<<(15-count);PUT(0);PUT(0);out[start]=control&255;out[start+1]=control>>8;
 free(prev);free(head);return p;
}
