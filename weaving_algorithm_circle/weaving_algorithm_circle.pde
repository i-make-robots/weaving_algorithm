//------------------------------------------------------
// circular weaving algorithm
// dan@marginallyclever.com 2016-08-05
// based on work by Petros Vrellis (http://artof01.com/vrellis/works/knit.html)
//------------------------------------------------------
// points around the circle
final int numberOfPoints = 230;
// self-documenting
final int numberOfLinesToDrawPerFrame = 50;
// self-documenting
final int totalLinesToDraw=8000;
// how thick are the threads?
final float lineWeight = 0.8;  // default 1
final float stringAlpha = 48; // 0...255 with 0 being totally transparent.
// ignore N nearest neighbors to this starting point
final int skipNeighbors=20;

// set true to start paused.  click the mouse in the screen to pause/unpause.
boolean paused=true;
// make this true to add one line per mouse click.
boolean singleStep=false;

// convenience colors.  RGBA. 
// Alpha is how dark is the string being added.  1...255 smaller is lighter.
// Messing with the alpha value seems to make a big difference!
final color white = color(255, 255, 255,stringAlpha);
final color black = color(0, 0, 0,stringAlpha);
final color blue = color(0, 0, 255,stringAlpha);
final color green = color(0, 255, 0,stringAlpha);
final color red = color(255, 0, 0,stringAlpha);


//------------------------------------------------------
float [] px = new float[numberOfPoints];
float [] py = new float[numberOfPoints];
float [] lengths = new float[numberOfPoints];
PImage img;
PGraphics dest; 


class WeavingThread {
  public color c;
  public int currentPoint;
  public String name;
  public char [] done;
};


class BestResult {
  public int maxA,maxB;
  public double maxValue;
  
  public BestResult( int a, int b, double v) {
    maxA=a;
    maxB=b;
    maxValue=v;
  }
};


class FinishedLine {
  public int start,end;
  public color c;
  
  public FinishedLine(int s,int e,color cc) {
    start=s;
    end=e;
    c=cc;
  }
};


ArrayList<FinishedLine> finishedLines = new ArrayList<FinishedLine>(); 
ArrayList<WeavingThread> threads = new ArrayList<WeavingThread>();

int totalLinesDrawn=0;

float scaleW,scaleH;
float diameter;
boolean ready;


// run once on start.
void setup() {
  // make the window.  must be (h*2,h+20)
  size(1600,820);

  ready=false;
  selectInput("Select an image file","inputSelected");
}


void inputSelected(File selection) {
  if(selection == null) {
    exit();
    return;
  }
  
  // load the image
  //img = loadImage("cropped.jpg");
  //img = loadImage("unnamed.jpg");
  img = loadImage(selection.getAbsolutePath());
  
  // crop image to square
  if(img.height<img.width) {
    img = img.get(0,0,img.height, img.height);
  } else {
    img = img.get(0,0,img.width, img.width);
  }
  
  // resize to fill window
  img.resize(width/2,width/2);

  dest = createGraphics(img.width, img.height);

  setBackgroundColor();
  
  // smash the image to grayscale
  //img.filter(GRAY);

  // find the size of the circle and calculate the points around the edge.
  diameter = ( img.width > img.height ) ? img.height : img.width;
  float radius = diameter/2;

  int i;
  for (i=0; i<numberOfPoints; ++i) {
    float d = PI * 2.0 * i/(float)numberOfPoints;
    px[i] = img.width /2 + cos(d) * radius;
    py[i] = img.height/2 + sin(d) * radius;
  }

  // a lookup table because sqrt is slow.
  for (i=0; i<numberOfPoints; ++i) {
    float dx = px[i] - px[0];
    float dy = py[i] - py[0];
    lengths[i] = sqrt(dx*dx+dy*dy);
  }
  
  threads.add(addLine(white,"white"));
  threads.add(addLine(black,"black"));
  //threads.add(addLine(blue,"blue"));
  //threads.add(addLine(color(230, 211, 133),"yellow"));
  ready=true;
}


void setBackgroundColor() {
/*
  // find average color of image
  float r=0,g=0,b=0;
  int size=img.width*img.height;
  int i;
  for(i=0;i<size;++i) {
    color c=img.pixels[i];
    r+=red(c);
    g+=green(c);
    b+=blue(c);
  }
  */
  // set to white
  float r=255,g=255,b=255;
  int size=1;
  
  dest.beginDraw();
  dest.background(
    r/(float)size,
    g/(float)size,
    b/(float)size);
  dest.endDraw();
}


WeavingThread addLine(color c,String name) {
  WeavingThread wt = new WeavingThread();
  wt.c=c;
  wt.name=name;
  wt.done = new char[numberOfPoints*numberOfPoints];

  // find best start
  wt.currentPoint = 0; 
  float bestScore = MAX_FLOAT;
  int i,j;
  for(i=0;i<numberOfPoints;++i) {
    for(j=i+1;j<numberOfPoints;++j) {
      float score = scoreLine(i,j,wt);
      if(bestScore>score) {
        bestScore = score;
        wt.currentPoint=i;
      }
    }
  }
  return wt;
}


void mouseReleased() {
  paused = paused ? false : true;
}


void draw() {
  if(!ready) return;
  
  // if we aren't done
  if (totalLinesDrawn<totalLinesToDraw) {
    if (!paused) {
      BestResult[] br = new BestResult[threads.size()];
      
      // draw a few at a time so it looks interactive.
      for(int i=0; i<numberOfLinesToDrawPerFrame; ++i) {
        // find the best thread for each color
        for(int j=0;j<threads.size();++j) {
          br[j]=findBest(threads.get(j));
        }
        // of the threads tested, which is best?
        double v = br[0].maxValue;
        int best = 0;
        for(int j=1;j<threads.size();++j) {
          if( v > br[j].maxValue ) {
            v = br[j].maxValue;
            best = j;
          }
        }
        // draw that best line.
        drawLine(threads.get(best),br[best].maxA,br[best].maxB);
      }
      if (singleStep) paused=true;
    }
    image(img, width/2, 0,width/2,height);
    image(dest, 0, 0, width/2, height);
  } else {
    // finished!    
    calculationFinished();
  }
  
  drawProgressBar();
}

void drawProgressBar() {
  float percent = (float)totalLinesDrawn / (float)totalLinesToDraw;

  strokeWeight(10);  // thick
  stroke(0,0,255,255);
  line(10, 5, (width-10), 5);
  stroke(0,255,0,255);
  line(10, 5, (width-10)*percent, 5);
}


// stop drawing and ask user where (if) to save CSV.
void calculationFinished() {
  noLoop();
  selectOutput("Select a destination CSV file","outputSelected");
}

// write the file if requested
void outputSelected(File output) {
  if(output==null) {
    return;
  }
  // write the file
  PrintWriter writer = createWriter(output.getAbsolutePath());
  writer.println("Color, Start, End");
  for(FinishedLine f : finishedLines ) {
    
    writer.println(getThreadName(f.c)+", "
                  +f.start+", "
                  +f.end+", ");
  }
  writer.close();
}


String getThreadName(color c) {
  for( WeavingThread w : threads ) {
    if(w.c == c) {
      return w.name;
    }
  }
  return "??";
}


// a weaving thread starts at wt.currentPoint.  for all other points Pn, look at the line between here and all other points Ln(Pn).  
// The Ln with the lowest score is the best fit.  zero would be a perfect score.
BestResult findBest(WeavingThread wt) {
  int i, j;
  double maxValue = Double.MAX_VALUE;
  int maxA = 0;
  int maxB = 0;

  // starting from the last line added
  i=wt.currentPoint;

  // uncomment this line to compare all starting points, not just the current starting point.  O(n*n) slower.
  //for(i=0;i<numberOfPoints;++i)
  {
    int i0 = i+1+skipNeighbors;
    int i1 = i+numberOfPoints-skipNeighbors;
    for (j=i0; j<i1; ++j) {
      int nextPoint = j % numberOfPoints;
      if(wt.done[i*numberOfPoints+nextPoint]>0) {
        //wt.done[i*numberOfPoints+nextPoint]--;
        //wt.done[nextPoint*numberOfPoints+i]--;
        continue;
      }
      double currentIntensity = scoreLine(i,nextPoint,wt);
      if ( maxValue > currentIntensity ) {
        maxValue = currentIntensity;
        maxA = i;
        maxB = nextPoint;
      }
    }
  }
  
  return new BestResult( maxA, maxB, maxValue );
}


// commit the new line to the destination image (our results so far)
// also remember the details for later.
void drawLine(WeavingThread wt,int maxA,int maxB) {
  //println(totalLinesDrawn+" : "+wt.name+"\t"+maxA+"\t"+maxB+"\t"+maxValue);
  
  drawToDest(maxA, maxB, wt.c);
  wt.done[maxA*numberOfPoints+maxB]=20;
  wt.done[maxB*numberOfPoints+maxA]=20;
  totalLinesDrawn++;
  
  // move to the end of the line.
  wt.currentPoint = maxB;
}

/**
 * Measure the change if thread wt were put here.
 * There is score A, the result so far: the difference between the original and the latest image.  A perfect match would be zero.  It is never a negative value.
 * There is score B, the result if latest were changed by the new thread. 
 */
float scoreLine(int i,int nextPoint,WeavingThread wt) {
  float sx=px[i];
  float sy=py[i];
  float dx = px[nextPoint] - sx;
  float dy = py[nextPoint] - sy;
  float len = diameter;
              //lengths[(int)abs(nextPoint-i)];
              //sqrt(dx*dx + dy*dy);

  color cc = wt.c;
  float ccAlpha = (alpha(cc)/255.0);
  //println(ccAlpha);
  
  float scoreBefore=0;
  float scoreAfter=0;
  float oldA=0,oldB=0;
  
  for(float k=0; k<len; k+=1) {
    float s = k/len; 
    int fx = (int)(sx + dx * s);
    int fy = (int)(sy + dy * s);

    color original = img.get(fx,fy);
    color current = dest.get(fx,fy);
    color newest = lerpColor(current,cc,ccAlpha);
    
    float newB = scoreColors(original,current);
    float newA = scoreColors(original,newest );
    scoreBefore += newB + abs(newB-oldB)*0.1;
    scoreAfter  += newA + abs(newA-oldA)*0.1;
    oldB=newB;
    oldA=newA;
  }
  
  return (scoreAfter - scoreBefore);
}

float scoreColors(color c0,color c1) {
  float r = red(  c0)-red(  c1);
  float g = green(c0)-green(c1);
  float b = blue( c0)-blue( c1);
  return (r*r + g*g + b*b);
}

void drawToDest(int start, int end, color c) {
  // draw darkest threads on screen.
  dest.beginDraw();
  dest.stroke(c);
  dest.strokeWeight(lineWeight);
  dest.line((float)px[start], (float)py[start], (float)px[end], (float)py[end]);
  dest.endDraw();
  finishedLines.add(new FinishedLine(start,end,c));
}
