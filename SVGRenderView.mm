//
//  SVGRenderView.m
//  SVGRender
//
//  Created by Joacim Magnusson on 2010-09-22.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGRenderView.h"
#include "agg_basics.h"
#include "agg_rendering_buffer.h"
#include "agg_rasterizer_scanline_aa.h"
#include "agg_scanline_p.h"
#include "agg_renderer_scanline.h"
#include "agg_pixfmt_rgba.h"
#include "agg_svg_parser.h"
#include "agg_pixfmt_rgb.h"
#include "agg_span_allocator.h"
#include "agg_span_gouraud_rgba.h"

@implementation SVGRenderView

agg::svg::path_renderer m_path;
enum
{
    frame_width = 800,
    frame_height = 600
};

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    
	agg::svg::parser p(m_path);
	p.parse("/testlevel.svg");
	m_path.arrange_orientations();
	
	typedef agg::span_allocator<agg::pixfmt_rgba32::color_type> span_alloc_type;
	typedef agg::span_gouraud_rgba<agg::pixfmt_rgba32::color_type> span_gen_type;
	typedef agg::renderer_base<agg::pixfmt_rgba32> renderer_base;
	typedef agg::renderer_scanline_aa_solid<renderer_base> ren_type_solid;
	
	unsigned int numBytes = frame_width * frame_height * 4;
	
	unsigned char* buffer = new unsigned char[numBytes];
	
    memset(buffer, 255, numBytes);
	
    agg::rendering_buffer rbuf(buffer, 
                               frame_width, 
                               frame_height, 
                               frame_width * 4);
	
    agg::pixfmt_rgba32 pixf(rbuf);
	renderer_base rb(pixf);
	
	rb.clear(agg::rgba(1,1,1,0));
	
	agg::rasterizer_scanline_aa<> ras;
	agg::scanline_p8 sl;
	agg::trans_affine mtx;
	
	mtx *= agg::trans_affine_translation(10, -1300);
	mtx *= agg::trans_affine_scaling(1);
	//mtx *= agg::trans_affine_rotation(agg::deg2rad(m_rotate.value()));
	
	ren_type_solid  ren_solid(rb);
	m_path.render(ras, sl, ren_solid, mtx, rb.clip_box(), 1.0);

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef bitmapContext = CGBitmapContextCreate(
													   buffer,
													   frame_width,
													   frame_height,
													   8, // bitsPerComponent
													   4*frame_width, // bytesPerRow
													   colorSpace,
													   kCGImageAlphaPremultipliedLast);
	
	CFRelease(colorSpace);
	
	CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
	
	NSImage *finalImage = [[NSImage alloc] initWithCGImage:cgImage size:NSMakeSize(frame_width, frame_height)];
	[finalImage drawInRect:NSMakeRect( 0, 0, frame_width, frame_height )
				 fromRect:NSMakeRect( 0, 0, [finalImage size].width, [finalImage size].height )
				operation:NSCompositeSourceOver
				 fraction:1.0];

	CFRelease(bitmapContext);

}

@end
