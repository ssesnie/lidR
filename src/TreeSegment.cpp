#include "TreeSegment.h"

Rcpp::NumericVector findEllipseParameters(boost::geometry::model::ring<point_t> &points);

TreeSegment::TreeSegment()
{
  nbPoints = 0;
  area = 0;
  diff_area = 0;
  dist = 0;
  scoreS = 0;
  scoreO = 0;
  scoreC = 0;
  scoreR = 0;
  scoreGlobal = 0;
}

TreeSegment::TreeSegment(PointXYZ &pt)
{
  nbPoints = 1;
  area = 0;
  diff_area = 0;
  dist = 0;

  points.push_back(pt);

  boost::geometry::set<0>(apex, pt.x);
  boost::geometry::set<1>(apex, pt.y);
  boost::geometry::append(convex_hull, apex);

  Zmax = pt;

  scoreS = 0;
  scoreO = 0;
  scoreC = 0;
  scoreR = 0;
  scoreGlobal = 0;
}

TreeSegment::~TreeSegment() {}

/*
* Given a new point pt, this function calculates:
* - new distance between points if there was no point or only one point in the initial tree
* - new area using boost::polygon function if the initial tree contains more than two points (update of associated convex hull)
*/
void TreeSegment::calculateArea()
{
  if (nbPoints <=  2)
    return;

  // Aera value without new point (previously stored)
  double area_noPt = area;
  double area_Pt = boost::geometry::area(convex_hull);
  diff_area = std::fabs(area_Pt - area_noPt);
  area = area_Pt;
  pointsCH.clear();
  pointsCH.assign(convex_hull.outer().begin(), convex_hull.outer().end());
  dist = 0;
}


/*
* Given a new point pt, this function calculates:
* - difference between old and new area (including pt) using boost::polygon function
* - if the initial tree contains more than two points (update of associated convex hull)
*/
double TreeSegment::testArea(PointXYZ &pt)
{
  point_t p(pt.x, pt.y);

  if(boost::geometry::covered_by(p, convex_hull))
    return 0;

  polygon old_hull(convex_hull);
  polygon new_hull;
  boost::geometry::append(old_hull, p);
  boost::geometry::convex_hull(old_hull, new_hull);

  double area_Pt = boost::geometry::area(new_hull);
  return(std::fabs(area_Pt - area));
}

/*
* Given a new point pt, this function calculates:
* - distance if only one point in initial tree
* - minimum distance between pt and all points of initial tree if there is more than one point
*/
double TreeSegment::testDist(PointXYZ &pt)
{
  if ( nbPoints == 1 )
  {
    double calculatedDist = std::sqrt( (points[0].x - pt.x)*(points[0].x - pt.x) + (points[0].y - pt.y)*(points[0].y - pt.y) );
    return calculatedDist;
  }
  else
  {
    //If more than one point in points --> Before distance calculation, search for closest point to pt
    double valRef = 0, val = 0;
    int keep = 0;
    valRef = euclidianDistance2D_inZ(pt, points[0]);
    for ( int i = 0; i < points.size(); i++ )
    {
      val = euclidianDistance2D_inZ(pt, points[i]);
      if ( valRef > val )
      {
        valRef = val;
        keep = i;
      }
    }
    double calculatedDist = std::sqrt( (points[keep].x - pt.x)*(points[keep].x - pt.x) + (points[keep].y - pt.y)*(points[keep].y - pt.y) );
    return calculatedDist;
  }
}

void TreeSegment::addPoint(PointXYZ &pt)
{
  nbPoints++;
  points.push_back(pt);

  point_t p(pt.x, pt.y);

  if(boost::geometry::covered_by(p, convex_hull))
    return;

  polygon old_hull(convex_hull);
  polygon new_hull;
  boost::geometry::append(old_hull, p);
  boost::geometry::convex_hull(old_hull, new_hull);
  convex_hull = new_hull;

  calculateArea();
}

//  JR: sert uniquement dans tree merge A supprimer plus stard.
void TreeSegment::updateArea()
{
  if ( nbPoints >= 3)
  {
    //Conversion from PointXYZ to point_t from boost library use
    mpoint_t pointsForPoly;
    for (unsigned int i = 0 ; i < points.size() ; i++ )
      boost::geometry::append( pointsForPoly, point_t(points[i].x, points[i].y) );

    //Assign boost points to polygon
    polygon poly2D;
    boost::geometry::assign_points(poly2D, pointsForPoly);
    boost::geometry::correct(poly2D);

    //Search for convex hull using previous polygon definition
    boost::geometry::model::ring<point_t> hull;
    boost::geometry::convex_hull(poly2D, hull);

    double area_Pt = boost::geometry::area( hull );
    area = area_Pt;
    pointsCH.clear();
    pointsCH.assign(hull.begin(), hull.end());
    dist = 0;
  }
  else if ( nbPoints == 2 )   //calculate distance
  {
    dist = std::sqrt( (points[0].x - points[1].x)*(points[0].x - points[1].x) + (points[0].y - points[1].y)*(points[0].y - points[1].y) );
  }
}

// Function that returns highest Z value in points of tree
double TreeSegment::findZMax()
{
  return (Zmax.z);
}

// Function that return lowest Z value in points of tree
double TreeSegment::findZMin()
{
  sort( points.begin(), points.end(), ZSortPointBis_increasing<PointXYZ>() );
  double Zmin = points[0].z;
  return (Zmin);
}

// Function that stores point coordinates of highest Z value in tree definition
void TreeSegment::getZMax()
{
  sort( points.begin(), points.end(), ZSortPointBis<PointXYZ>() );
  Zmax = points[0];
}

// Function that returns point coordinates of highest Z value in points of tree
void TreeSegment::getZMax(PointXYZ &pt)
{
  sort( points.begin(), points.end(), ZSortPointBis<PointXYZ>() );
  pt = points[0];
}

polygon TreeSegment::get_convex_hull()
{
  return convex_hull;
}

point_t TreeSegment::get_apex()
{
  return apex;
}

// Function that stores ID of tree in a reference vector of int --> idResult
void TreeSegment::editIdResult (std::vector<int> &idResult, int &index)
{
  for (int i = 0; i < nbPoints ; i++)
  {
    if ( idResult[points[i].id] == 0)
      idResult[points[i].id] = index;
    /*else
    idResult[points[i].id] = INT16_MAX;      //pour tester si on remplace des IDs d'arbres précédemment trouvés*/
  }
  index++;
}

/*
* Function to improve detection and removal of small false positive depending on minimal number of point per tree segment
* trees: number of detected trees
* k: number of nearest neighbours
* D: local density of the 3D points in the horizontal plane within the tree segment (page 101 after Eq.5)
*/
void TreeSegment::getSize(int k)
{
  //Search for Zmax point in tree segment  --> H
  double H = findZMax();     //page 101 after Eq.5
  //Point density calculation --> D
  double D = 0;
  if (area != 0 )
    D = nbPoints / area;
  else
    D = nbPoints / dist;     //TODO:que faire pour la distance????
  //Treshold calculation (page 101 Eq.5)
  double threshold = k * D * std::log(H);

  //Comparison N and threshold (page 101 Eq.4)
  if (nbPoints > threshold)
    scoreS = 1;
  else
    scoreS = (nbPoints/threshold);
}

/*
* Function that evaluates the eccentrictity of M (highest point of tree segment) to the gravity center G
* of the point cloud associated with the tree segment -->page 101
*/
void TreeSegment::getOrientation()
{
  scoreO = 0;

  if ( area != 0 && points.size() > 2 && pointsCH.size() > 2 )
  {
    //searching for highest point of tree segment
    getZMax();
    PointXYZ M = Zmax;

    //searching for gravity center G of the point cloud
    double dx = 0, dy = 0;
    for (int j = 0 ; j < nbPoints; j++ )
    {
      dx += points[j].x;
      dy += points[j].y;
    }
    double xG = dx/nbPoints;
    double yG = dy/nbPoints;
    PointXYZ G = M;
    G.x = xG; G.y = yG; //--> TODO:faire la moyenne des coordonees de tous les points ou seulement ceux du convex hull??

    //Calculation of planimetric distance between M and G
    double dist_MG = euclidianDistance2D_inZ( M, G );

    //Calculation of average distance of G to the borders of the convex hull
    PointXYZ pt (boost::geometry::get<0>(pointsCH[0]), boost::geometry::get<1>(pointsCH[0]));
    double dist_GCH = euclidianDistance2D_inZ( M, pt );
    int ind = 0;
    for (int j = 1; j < pointsCH.size(); j++ )
    {
      ind++;
      pt.x = boost::geometry::get<0>(pointsCH[j]);
      pt.y = boost::geometry::get<1>(pointsCH[j]);
      dist_GCH += euclidianDistance2D_inZ( M, pt );
    }
    dist_GCH /= pointsCH.size();

    //Comparison dist_MG and dist_GCH (page 101 Eq. 7)
    if ( dist_MG <= dist_GCH/2.0 )
    {
      scoreO += (1.0 - 2.0*(dist_MG/dist_GCH));
    }
  }
}

void TreeSegment::getRegularity()
{
  std::vector<double> planimetricDist_MCH;

  scoreR = 0;
  if ( area != 0 && nbPoints > 2 && pointsCH.size() > 2 )
  {
    //Area value retrieval from trees
    double area_CH = area;

    planimetricDist_MCH.clear();
    //searching for highest point of tree segment
    getZMax();
    PointXYZ M = Zmax;
    PointXYZ pt (boost::geometry::get<0>(pointsCH[0]), boost::geometry::get<1>(pointsCH[0]));
    planimetricDist_MCH.push_back( euclidianDistance2D_inZ( M, pt ) );
    for (int j = 1; j < pointsCH.size(); j++ )
    {
      pt.x = boost::geometry::get<0>(pointsCH[j]);
      pt.y = boost::geometry::get<1>(pointsCH[j]);
      planimetricDist_MCH.push_back( euclidianDistance2D_inZ( M, pt ) );
    }
    sort(planimetricDist_MCH.begin(), planimetricDist_MCH.end());
    int index_percentile95 = round(planimetricDist_MCH.size() * 0.95);

    double radius= planimetricDist_MCH[index_percentile95-1];

    scoreR = (area_CH / (PI*radius*radius )); //page 101 Eq. 8
  }
}

//http://nicky.vanforeest.com/misc/fitEllipse/fitEllipse.html
Rcpp::NumericVector findEllipseParameters(boost::geometry::model::ring<point_t> &points)
{

  int nbPoint = points.size();
  dmat data(2,nbPoint);

  dmat center = zeros(1,2);
  for (int i = 0; i < nbPoint ; i++ )
  {
    data(0,i) = boost::geometry::get<0>(points[i]);
    data(1,i) = boost::geometry::get<1>(points[i]);
  }

  unique(data);

  //means of eachcoordinates --> ellipse center
  for (int i = 0; i < data.n_rows ; i++ )
  {
    center(0,0) += data(0,i);
    center(0,1) += data(1,i);
  }
  center(0,0) /= data.n_rows;
  center(0,1) /= data.n_rows;

  //Covariance C of
  dmat C = (data*data.t()) - center.t()*center;

  mat PC = princomp(C);
  mat data_PCA_2d = data.t() * PC;

  double max_x = max(data_PCA_2d.col(0));
  double max_y = max(data_PCA_2d.col(1));

  double min_x = min(data_PCA_2d.col(0));
  double min_y = min(data_PCA_2d.col(1));

  double half_axis_length1 = fabs(max_x - min_x);
  double half_axis_length2 = fabs(max_y - min_y);

  Rcpp::NumericVector L = Rcpp::NumericVector::create(half_axis_length1,half_axis_length2);

  return (L);
}

/*
 * Hypothesis --> each tree segment should be an approximate circle
 * This function evaluates each tree circularity (ratio between major and minor axes of the smallest 2D projection ellipse) (page 101)
 */
void TreeSegment::getCircularity()
{
  scoreC = 0;

  if ( area != 0 && points.size() > 2 && pointsCH.size() > 2 )
  {
    //calculate major and minor axes (A and B)
    Rcpp::NumericVector E = findEllipseParameters(pointsCH);
    double A = E(0) > E(1)? E(0): E(1);
    double B = E(0) < E(1)? E(0): E(1);
    if (B != 0)
      scoreC += (A/B);              //page 101 Eq.6
  }
  scoreGlobal = (scoreS + scoreO + scoreR + scoreC) / 4.0;   //Faire fonction spécifique éventuellement(plus propre)

}

double TreeSegment::getScore( int k )
{
  //enlever plus tard les 4 scores individuels et ne conserver que le score moyen
  getSize(k);
  getOrientation();
  getRegularity();
  getCircularity();   //scoreGlobal calculé ici --> bof
}

void TreeSegment::apply2DFilter(std::vector<PointXYZ> &subProfile, std::vector<PointXYZ> &subProfileSubset )
{
  double meanValueForThreshold = 0;
  std::vector<double> dist;
  double stdValueForThreshold = 0;
  double val = 0;
  // Euclidian Distance calculation in 2D for all neighbours regarding the reference point (storage in Z value)
  for (unsigned int i = 1; i < subProfile.size(); i++ )
  {
    val = euclidianDistance2D_inZ( subProfile[0], subProfile[i] );
    meanValueForThreshold += val;
    dist.push_back( val );
  }

  //--------------------------------------------------------------------------------------
  // Threshold definition (page 100 'segmentation principles')
  // defined as the mean plus twice the std of the planimetric distances of a subset of points
  meanValueForThreshold /= (double)(subProfile.size() - 1);
  double sum = 0;
  for(unsigned int i = 0; i < dist.size(); i++)
    sum += (dist[i]-meanValueForThreshold) * (dist[i]-meanValueForThreshold);

  stdValueForThreshold = std::sqrt( sum / (double) dist.size() );

  double threshold = meanValueForThreshold + 2*stdValueForThreshold;
  //--------------------------------------------------------------------------------------
  // Keeping all points below threshold and storage of their IDs
  int i = 0, keep = 0;
  subProfileSubset.push_back(subProfile[0]);
  while ( (i < subProfile.size()-1) && (dist[i] <= threshold) )
  {
    subProfileSubset.push_back( subProfile[i+1] );
    i++;
  }
}