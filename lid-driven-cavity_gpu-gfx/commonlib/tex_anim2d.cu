/* tex_anim2d.cu
 * 2-dim. GPU texture animation 
 * Ernest Yeung  ernestyalumni@gmail.com
 * 20160720
 */
#include "tex_anim2d.h"
  
int iterationCount = 0 ;


// interactions

void keyboard_func( unsigned char key, int x, int y) {

	if (key==27) {
//		std::exit(0) ;
		exit(0);
	}
	glutPostRedisplay();
}
	
void mouse_func( int button, int state, int x, int y ) {
	glutPostRedisplay();
}

void idle() {
	++iterationCount;
	glutPostRedisplay();
}

void printInstructions() {
	printf("2 dim. texture animation \n"

			"Exit                           : Esc\n"
	
	);
}

// make* functions make functions to pass into OpenGL (note OpenGL is inherently a C API
void make_draw_texture(int w, int h) {
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, 
		GL_UNSIGNED_BYTE, NULL);
	glEnable(GL_TEXTURE_2D);

	glBegin(GL_QUADS);
	glTexCoord2f(0.0f, 0.0f); glVertex2f(0,0);
	glTexCoord2f(0.0f, 1.0f); glVertex2f(0,h);
	glTexCoord2f(1.0f, 1.0f); glVertex2f(w,h);
	glTexCoord2f(1.0f, 0.0f); glVertex2f(w,0);  // glVertex2f(float(w),0);
	glEnd();
	
	glDisable(GL_TEXTURE_2D);
}	

/* NOTE: this version of float_to_char wants to access only the "internal"
 * cells, or the so-called fluid cells (of Griebel, et. al.), NOT the 
 * boundary cells.  Hence the indexing isn't 1-to-1 */

__global__ void float_to_char( uchar4* dev_out, const float* outSrc, const int L_x, const int L_y) {
	const int k_x = threadIdx.x + blockDim.x * blockIdx.x ;
	const int k_y = threadIdx.y + blockDim.y * blockIdx.y ;
	
	const int k = k_x + k_y * blockDim.x * gridDim.x;
	if ((k_x >= L_x) || (k_y >= L_y)) {
		return ; }
		
	/* staggered_k is the index on the "staggered grid" which INCLUDES
	 * boundary cells: [0,L_X+1] x [ 0,L_Y+1]	
	 * */
	const int staggered_k = (k_x+1) + (L_x + 2) * (k_y+1);
		
	dev_out[k].x = 0;
	dev_out[k].z = 0;
	dev_out[k].y = 0;
	dev_out[k].w = 255;
	
	float value = outSrc[staggered_k] ; 

	// convert to long rainbox RGB*
	// 1. convert to [0.0,1.0] scale from [minval,maxval] (set minval,maxval MANUALLY)
	// MANUALLY change minval, maxval
	const float minval = -0.7;
	const float maxval = 1.0;

	value = (value - minval) / ( maxval - minval) ; 
	if (value < 0.00001 ) { value = 0.0; }
	else if (value > 1.0 ) { value = 1.0; }
	
	// 2. convert to long rainbox RGB*
	value = value / 0.20;
	int valueint  = ((int) floorf( value )); // this is the integer part
	int valuefrac = ((int) floorf( 255*(value - valueint)) );
	
	switch( valueint )
	{
		case 0: dev_out[k].x = 255; dev_out[k].y = valuefrac; dev_out[k].z = 0;
		dev_out[k].w = 255;
		break;
		case 1: dev_out[k].x = 255- valuefrac; dev_out[k].y = 255; dev_out[k].z = 0;
		dev_out[k].w = 255;
		break;
		case 2: dev_out[k].x = 0; dev_out[k].y = 255; dev_out[k].z = valuefrac;
		dev_out[k].w = 255;
		break;
		case 3: dev_out[k].x = 0; dev_out[k].y = 255- valuefrac; dev_out[k].z = 255;
		dev_out[k].w = 255;
		break;
		case 4: dev_out[k].x = valuefrac; dev_out[k].y = 0; dev_out[k].z = 255;
		dev_out[k].w = 255;
		break;
		case 5: dev_out[k].x = 255; dev_out[k].y = 0; dev_out[k].z = 255;
		dev_out[k].w = 255;
		break;
	}
}


// from physical scalar values to color intensities on an OpenGL bitmap
__global__ void floatux_to_char( uchar4* dev_out, cudaSurfaceObject_t uSurf, 
									const int L_x, const int L_y) {
	const int k_x = threadIdx.x + blockDim.x * blockIdx.x ; 
	const int k_y = threadIdx.y + blockDim.y * blockIdx.y ; 
	
	const int k = k_x + k_y * blockDim.x *gridDim.x ; 
	if ((k_x >= L_x ) || (k_y >= L_y)) {
		return ; }
	
	dev_out[k].x = 0;
	dev_out[k].y = 0;
	dev_out[k].z = 0;
	dev_out[k].w = 255;
	 
	float2 tempu; 
	surf2Dread(&tempu, uSurf, k_x * 8, k_y );

	// clipping part
	const float scale = 2.f ;
	const float newval = tempu.x / scale; 
	 
	int n = 256 * newval ; 
	n = max( min( n, 255) , 0 ) ; 
	// END of clipping part
	 
	const unsigned char intensity = n ; 
	dev_out[k].x = intensity ;  // higher magnitude -> more red
	dev_out[k].z = 255 - intensity ; // lower magnitude -> more blue
}
