# -*- coding: utf-8 -*-
"""
Genera Matriz_IAM_DaianaAranda.pdf

El documento se construye por código para que sea reproducible: cualquier
corrección se hace en este archivo y se regenera el PDF, en lugar de editar
un binario a mano.

    pip install reportlab
    python generar_matriz_iam.py
"""
import os
from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (Paragraph, SimpleDocTemplate, Spacer,
                                Table, TableStyle)

# ----------------------------------------------------------------------------
# Identidad visual
# ----------------------------------------------------------------------------
INK    = HexColor('#131C26')
SOFT   = HexColor('#3D4C5B')
MUTED  = HexColor('#5A6B7C')
LOCK   = HexColor('#A9700E')   # acento reservado a decisiones de seguridad
LINE   = HexColor('#C9D2DB')
HAIR   = HexColor('#E4E9EE')
ROWALT = HexColor('#F5F7F9')
HEADBG = HexColor('#1E2A36')
DENYBG = HexColor('#FBF3E4')

PAGE_W, PAGE_H = A4
MARGIN = 1.6 * cm
USABLE = PAGE_W - 2 * MARGIN

AUTOR  = "Daiana Aranda"
TITULO = "Matriz de Control de Acceso IAM"
SUBT   = "Plataforma de datos en streaming - Kinesis, Glue y S3"

S = {}
S['title']    = ParagraphStyle('title', fontName='Helvetica-Bold', fontSize=23, leading=27, textColor=INK, spaceAfter=6)
S['subtitle'] = ParagraphStyle('subtitle', fontName='Helvetica', fontSize=12, leading=16, textColor=SOFT, spaceAfter=18)
S['h1']       = ParagraphStyle('h1', fontName='Helvetica-Bold', fontSize=13.5, leading=17, textColor=INK, spaceBefore=17, spaceAfter=7)
S['h2']       = ParagraphStyle('h2', fontName='Helvetica-Bold', fontSize=10.5, leading=14, textColor=INK, spaceBefore=12, spaceAfter=5)
S['eyebrow']  = ParagraphStyle('eyebrow', fontName='Helvetica-Bold', fontSize=7.5, leading=10, textColor=MUTED, spaceAfter=3)
S['body']     = ParagraphStyle('body', fontName='Helvetica', fontSize=9.2, leading=13.4, textColor=SOFT, alignment=TA_JUSTIFY, spaceAfter=7)
S['cell']     = ParagraphStyle('cell', fontName='Helvetica', fontSize=7.3, leading=9.3, textColor=SOFT)
S['cellb']    = ParagraphStyle('cellb', fontName='Helvetica-Bold', fontSize=7.3, leading=9.3, textColor=INK)
S['mono']     = ParagraphStyle('mono', fontName='Courier', fontSize=6.8, leading=8.9, textColor=INK)
S['monod']    = ParagraphStyle('monod', fontName='Courier-Bold', fontSize=6.8, leading=8.9, textColor=LOCK)
S['th']       = ParagraphStyle('th', fontName='Helvetica-Bold', fontSize=7.3, leading=9.3, textColor=colors.white)
S['code']     = ParagraphStyle('code', fontName='Courier', fontSize=7.0, leading=9.6, textColor=INK)


def P(t, st='cell'):
    return Paragraph(t, S[st])


def header_footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 7.2)
    canvas.setFillColor(MUTED)
    canvas.drawString(MARGIN, PAGE_H - MARGIN + 0.32 * cm, TITULO.upper())
    canvas.drawRightString(PAGE_W - MARGIN, PAGE_H - MARGIN + 0.32 * cm, "Kinesis / Glue / S3")
    canvas.setStrokeColor(LINE)
    canvas.setLineWidth(0.5)
    canvas.line(MARGIN, PAGE_H - MARGIN + 0.18 * cm, PAGE_W - MARGIN, PAGE_H - MARGIN + 0.18 * cm)
    canvas.line(MARGIN, MARGIN - 0.30 * cm, PAGE_W - MARGIN, MARGIN - 0.30 * cm)
    canvas.drawString(MARGIN, MARGIN - 0.72 * cm, AUTOR)
    canvas.drawRightString(PAGE_W - MARGIN, MARGIN - 0.72 * cm, "Página %d" % doc.page)
    canvas.restoreState()


def tabla(data, widths, deny_rows=()):
    t = Table(data, colWidths=widths, repeatRows=1, hAlign='LEFT')
    cmds = [
        ('BACKGROUND', (0, 0), (-1, 0), HEADBG),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('GRID', (0, 0), (-1, -1), 0.4, HAIR),
        ('BOX', (0, 0), (-1, -1), 0.6, LINE),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 3.6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3.6),
    ]
    for i in range(1, len(data)):
        if i in deny_rows:
            cmds.append(('BACKGROUND', (0, i), (-1, i), DENYBG))
        elif i % 2 == 0:
            cmds.append(('BACKGROUND', (0, i), (-1, i), ROWALT))
    t.setStyle(TableStyle(cmds))
    return t


def code_block(lines):
    esc = []
    for l in lines:
        l = l.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        esc.append(l.replace(' ', '&nbsp;'))
    t = Table([[Paragraph('<br/>'.join(esc), S['code'])]], colWidths=[USABLE], hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), HexColor('#F7F9FB')),
        ('BOX', (0, 0), (-1, -1), 0.5, LINE),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        ('TOPPADDING', (0, 0), (-1, -1), 7),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
    ]))
    return t


def callout(titulo, texto):
    st_t = ParagraphStyle('ct', fontName='Helvetica-Bold', fontSize=7.6, leading=10, textColor=LOCK)
    st_b = ParagraphStyle('cb', fontName='Helvetica', fontSize=8.4, leading=12, textColor=SOFT, alignment=TA_JUSTIFY)
    t = Table([[Paragraph(titulo, st_t)], [Paragraph(texto, st_b)]], colWidths=[USABLE], hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), DENYBG),
        ('LINEBEFORE', (0, 0), (0, -1), 2.2, LOCK),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ('TOPPADDING', (0, 0), (0, 0), 8),
        ('BOTTOMPADDING', (0, 0), (0, 0), 2),
        ('TOPPADDING', (0, 1), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 1), (-1, -1), 8),
    ]))
    return t


# ============================================================================
# CONTENIDO
# ============================================================================
story = []
W3 = [4.5 * cm, 4.3 * cm, 9.0 * cm]
TH3 = [P('Acción de la API', 'th'), P('Recurso (ARN)', 'th'), P('Justificación de seguridad', 'th')]

# --------------------------------------------------------------- portada ---
story.append(Paragraph('MATRIZ DE CONTROL DE ACCESO', S['eyebrow']))
story.append(Paragraph(TITULO, S['title']))
story.append(Paragraph(SUBT, S['subtitle']))

meta = [
    [P('Autora', 'cellb'), P(AUTOR), P('Entorno', 'cellb'), P('dev - cuenta 111122223333')],
    [P('Servicios', 'cellb'), P('Kinesis Data Streams, AWS Glue, Amazon S3, AWS KMS'), P('Región', 'cellb'), P('us-east-1')],
    [P('Principios', 'cellb'), P('Mínimo privilegio, separación de responsabilidades, blast radius acotado'), P('Versión', 'cellb'), P('1.0')],
]
t = Table(meta, colWidths=[2.4 * cm, 7.6 * cm, 3.0 * cm, 4.8 * cm], hAlign='LEFT')
t.setStyle(TableStyle([
    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ('LINEBELOW', (0, 0), (-1, -2), 0.4, HAIR),
    ('LEFTPADDING', (0, 0), (0, -1), 0),
    ('TOPPADDING', (0, 0), (-1, -1), 5),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
]))
story.append(t)

# ------------------------------------------------------------ 1. intro ---
story.append(Paragraph('1. Introducción', S['h1']))
story.append(Paragraph(
    'Este documento define el modelo de permisos de una plataforma de ingesta en tiempo real que '
    'recibe eventos en <b>Kinesis Data Streams</b>, los persiste en la capa RAW de un Data Lake en '
    '<b>Amazon S3</b> y los cataloga en <b>AWS Glue</b>. Tanto el stream como los objetos están '
    'cifrados con una clave gestionada por el cliente (CMK) de <b>AWS KMS</b>.', S['body']))
story.append(Paragraph(
    'El diseño parte de una premisa: los tres actores que operan la plataforma tienen necesidades '
    'disjuntas, y confundirlas es la principal fuente de exposición. El pipeline de despliegue '
    '<b>crea</b> los recursos pero no debe leer los datos que contienen; el proceso de ingesta '
    '<b>mueve</b> datos pero no debe alterar la infraestructura; el ingeniero <b>observa</b> pero no '
    'modifica nada. Cada rol recibe únicamente las acciones necesarias para su función, acotadas a '
    'ARNs explícitos.', S['body']))
story.append(Paragraph(
    'Los permisos descritos corresponden al entorno de desarrollo. Producción replica la estructura '
    'en una cuenta de AWS distinta (444455556666), con sus propios recursos, su propia CMK y sus '
    'propios roles: no existe ningún principal con acceso simultaneo a ambos entornos.', S['body']))

story.append(Paragraph('1.1 Convenciones de nomenclatura', S['h2']))
story.append(Paragraph(
    'Para mantener las tablas legibles, los ARNs completos se abrevian con las referencias '
    'siguientes. Ninguna política de este documento usa comodines en el campo Resource para acciones '
    'de escritura.', S['body']))

conv = [
    [P('Referencia', 'th'), P('ARN completo', 'th'), P('Descripción', 'th')],
    [P('${STREAM}', 'mono'), P('arn:aws:kinesis:us-east-1:111122223333:<br/>stream/ingesta-streaming-dev', 'mono'), P('Stream que recibe los eventos')],
    [P('${BUCKET}', 'mono'), P('arn:aws:s3:::datalake-raw-dev-111122223333', 'mono'), P('Bucket de la capa RAW del Data Lake')],
    [P('${KMS}', 'mono'), P('arn:aws:kms:us-east-1:111122223333:key/a1b2c3d4<br/>(alias/datalake-dev)', 'mono'), P('CMK que cifra el stream y los objetos')],
    [P('${GLUE_DB}', 'mono'), P('arn:aws:glue:us-east-1:111122223333:<br/>database/datalake_dev', 'mono'), P('Base de datos del catalogo')],
    [P('${GLUE_TBL}', 'mono'), P('arn:aws:glue:us-east-1:111122223333:<br/>table/datalake_dev/raw_eventos', 'mono'), P('Tabla catalogada de la capa RAW')],
    [P('${LOG_GRP}', 'mono'), P('arn:aws:logs:us-east-1:111122223333:log-group:<br/>/aws/lambda/ingesta-kinesis-s3-dev:*', 'mono'), P('Grupo de logs del proceso de ingesta')],
    [P('${TFSTATE}', 'mono'), P('arn:aws:s3:::tfstate-dev', 'mono'), P('Bucket del state de Terraform, distinto del de datos')],
    [P('${LOCK_TBL}', 'mono'), P('arn:aws:dynamodb:us-east-1:111122223333:<br/>table/locks-dev', 'mono'), P('Tabla de locking del state')],
]
story.append(tabla(conv, [2.5 * cm, 7.3 * cm, 8.0 * cm]))

# --------------------------------------- 2. control plane vs data plane ---
story.append(Paragraph('2. Separación Control Plane / Data Plane', S['h1']))
story.append(Paragraph(
    'La distinción que estructura toda la matriz separa las operaciones que actúan <b>sobre el '
    'contenedor</b> de las que actúan <b>sobre el contenido</b>. Son planos distintos de la API de '
    'AWS y deben estar en manos distintas.', S['body']))

planos = [
    [P('Dimensión', 'th'), P('Control Plane', 'th'), P('Data Plane', 'th')],
    [P('Qué manipula', 'cellb'), P('El recurso como objeto de infraestructura: existencia, capacidad, cifrado, políticas'), P('Los registros y archivos que viven dentro del recurso')],
    [P('Ejemplos', 'cellb'), P('kinesis:CreateStream<br/>s3:CreateBucket<br/>glue:CreateTable<br/>iam:PutRolePolicy', 'mono'), P('kinesis:GetRecords<br/>s3:PutObject<br/>glue:StartJobRun<br/>kms:GenerateDataKey', 'mono')],
    [P('Quien lo ejerce', 'cellb'), P('Rol de Despliegue (Terraform / CI-CD)'), P('Rol de Ejecución (servicio de ingesta)')],
    [P('Frecuencia', 'cellb'), P('Baja: solo durante despliegues'), P('Alta: continua, por cada evento procesado')],
    [P('Auditoría', 'cellb'), P('CloudTrail management events, activos por defecto'), P('CloudTrail data events, requieren habilitación explícita')],
]
story.append(tabla(planos, [3.0 * cm, 7.4 * cm, 7.4 * cm]))

story.append(Paragraph('2.1 Matriz resumen de responsabilidades', S['h2']))
resumen = [
    [P('Rol', 'th'), P('Control Plane', 'th'), P('Data Plane', 'th'), P('Alcance', 'th'), P('Credencial', 'th')],
    [P('Despliegue (CI/CD)', 'cellb'), P('SI, ciclo de vida completo'), P('NO, salvo su propio state'), P('Cuenta dev'), P('OIDC federado, sin claves de larga vida')],
    [P('Ejecución (servicio)', 'cellb'), P('NO'), P('SI, lectura de stream y escritura en RAW'), P('Stream y prefijo raw/'), P('Credenciales temporales del servicio')],
    [P('Operador (humano)', 'cellb'), P('NO'), P('Solo lectura'), P('Cuenta dev únicamente'), P('AssumeRole con MFA obligatorio')],
]
story.append(tabla(resumen, [3.0 * cm, 3.2 * cm, 4.0 * cm, 2.8 * cm, 4.8 * cm]))

story.append(Spacer(1, 0.3 * cm))
story.append(callout(
    'EL ERROR QUE ESTA SEPARACIÓN EVITA',
    'Confundir despliegue con ejecución es el fallo más frecuente. El pipeline necesita crear el '
    'bucket, pero no leer los datos que se guardan adentro. Si el rol de CI/CD tuviera s3:GetObject, '
    'cualquier compromiso del repositorio o de un runner se convertiría en una fuga del Data Lake '
    'completo, sin necesidad de tocar la infraestructura.'))

# -------------------------------------------------------- 3. despliegue ---
story.append(Paragraph('3. Rol de Despliegue (Terraform / CI-CD)', S['h1']))
story.append(Paragraph(
    '<b>Nombre:</b> <font face="Courier">role-terraform-deploy-dev</font> &nbsp;&nbsp; '
    '<b>Plano:</b> Control Plane &nbsp;&nbsp; <b>Uso:</b> ejecuciones de <font face="Courier">'
    'terraform plan/apply</font> desde el pipeline.', S['body']))

story.append(Paragraph('3.1 Trust Policy', S['h2']))
story.append(Paragraph(
    'El rol se asume por federación OIDC desde GitHub Actions. No existen claves de acceso de larga '
    'vida almacenadas en el repositorio: el pipeline obtiene credenciales temporales por ejecución. '
    'La condición sobre <font face="Courier">sub</font> limita el permiso a la rama principal de un '
    'repositorio concreto, de modo que un fork o una rama arbitraria no pueden asumirlo.', S['body']))
story.append(code_block([
    '{',
    '  "Version": "2012-10-17",',
    '  "Statement": [{',
    '    "Effect": "Allow",',
    '    "Principal": {',
    '      "Federated": "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"',
    '    },',
    '    "Action": "sts:AssumeRoleWithWebIdentity",',
    '    "Condition": {',
    '      "StringEquals": {',
    '        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"',
    '      },',
    '      "StringLike": {',
    '        "token.actions.githubusercontent.com:sub":',
    '          "repo:arandadaiana/proyecto_data_engineering:ref:refs/heads/main"',
    '      }',
    '    }',
    '  }]',
    '}',
]))

story.append(Paragraph('3.2 Permisos', S['h2']))
desp = [
    TH3,
    [P('kinesis:CreateStream<br/>kinesis:DeleteStream<br/>kinesis:UpdateShardCount<br/>kinesis:StartStreamEncryption<br/>kinesis:AddTagsToStream', 'mono'), P('${STREAM}', 'mono'),
     P('Ciclo de vida del stream. Acotado al ARN del entorno: el rol de dev no alcanza el stream de producción, que vive en otra cuenta.')],
    [P('kinesis:DescribeStream<br/>kinesis:DescribeStreamSummary<br/>kinesis:ListTagsForStream', 'mono'), P('${STREAM}', 'mono'),
     P('Lectura de metadatos que Terraform necesita para calcular el plan. Devuelven configuración, nunca registros del stream.')],
    [P('s3:CreateBucket<br/>s3:PutBucketVersioning<br/>s3:PutEncryptionConfiguration<br/>s3:PutBucketPublicAccessBlock<br/>s3:PutLifecycleConfiguration', 'mono'), P('${BUCKET}', 'mono'),
     P('Configuración a nivel bucket, que es control plane puro. Incluye las medidas defensivas del propio bucket: cifrado y bloqueo de acceso público.')],
    [P('s3:GetBucketLocation<br/>s3:GetBucketVersioning<br/>s3:GetEncryptionConfiguration<br/>s3:ListBucket', 'mono'), P('${BUCKET}', 'mono'),
     P('Lectura de configuración para el refresh del state. ListBucket enumera nombres de objeto, no su contenido.')],
    [P('s3:GetObject<br/>s3:PutObject<br/>s3:DeleteObject', 'monod'), P('${BUCKET}/*', 'monod'),
     P('<b>NO SE CONCEDE.</b> Exclusión deliberada y central del diseño: el pipeline crea el contenedor pero nunca accede a los datos. Una credencial de CI comprometida no puede exfiltrar el Data Lake.')],
    [P('s3:GetObject<br/>s3:PutObject', 'mono'), P('${TFSTATE}/dev/*', 'mono'),
     P('Unica excepción de objetos, y sobre un bucket distinto: Terraform lee y escribe su propio state. Acotada al prefijo del entorno.')],
    [P('dynamodb:GetItem<br/>dynamodb:PutItem<br/>dynamodb:DeleteItem', 'mono'), P('${LOCK_TBL}', 'mono'),
     P('State locking. Sin DeleteTable ni Scan: solo las tres operaciones que el backend necesita sobre el item de bloqueo.')],
    [P('glue:CreateDatabase<br/>glue:CreateTable<br/>glue:UpdateTable<br/>glue:DeleteTable<br/>glue:CreateJob / UpdateJob', 'mono'), P('${GLUE_DB}<br/>${GLUE_TBL}', 'mono'),
     P('Definición del catalogo y de los jobs como artefactos de infraestructura.')],
    [P('glue:StartJobRun', 'monod'), P('-', 'monod'),
     P('<b>NO SE CONCEDE.</b> Ejecutar un job es data plane. Si el pipeline pudiera lanzarlo, heredaría de hecho los permisos del rol de ejecución y la separación quedaría anulada.')],
    [P('iam:CreateRole / DeleteRole<br/>iam:PutRolePolicy<br/>iam:AttachRolePolicy<br/>iam:GetRole / TagRole', 'mono'), P('arn:aws:iam::111122223333:<br/>role/datalake-*', 'mono'),
     P('Crea los roles de servicio del proyecto. Acotado por prefijo de nombre: no puede modificar roles de administración, de auditoría, ni el suyo propio.')],
    [P('iam:PassRole<br/><i>con Condition</i><br/>iam:PassedToService in<br/>{lambda, glue}.amazonaws.com', 'mono'), P('arn:aws:iam::111122223333:<br/>role/datalake-ingesta-exec-dev', 'mono'),
     P('Vector clásico de escalada de privilegios. Sin la condición, el pipeline podría asignar un rol privilegiado a un recurso que el mismo controla y heredar sus permisos.')],
    [P('kms:CreateKey / CreateAlias<br/>kms:PutKeyPolicy<br/>kms:DescribeKey<br/>kms:ScheduleKeyDeletion', 'mono'), P('${KMS}', 'mono'),
     P('Ciclo de vida de la clave de cifrado.')],
    [P('kms:Decrypt<br/>kms:GenerateDataKey', 'monod'), P('${KMS}', 'monod'),
     P('<b>NO SE CONCEDE.</b> El rol crea la clave pero no puede usarla. Aunque por un error de política obtuviera un objeto del bucket, seguiría siendo incapaz de descifrarlo: son dos barreras independientes.')],
]
story.append(tabla(desp, W3, deny_rows=(5, 9, 13)))

story.append(Spacer(1, 0.25 * cm))
story.append(callout(
    'DENY EXPLÍCITO COMPLEMENTARIO',
    'La política cierra con un Deny sobre todo ARN de la cuenta 444455556666 y sobre iam:* fuera del '
    'prefijo datalake-*. En IAM un Deny explícito prevalece siempre sobre cualquier Allow, incluso '
    'sobre uno agregado después por error. Funciona como red de seguridad frente a cambios futuros.'))

# --------------------------------------------------------- 4. ejecución ---
story.append(Paragraph('4. Rol de Ejecución del Proceso (Service Role)', S['h1']))
story.append(Paragraph(
    '<b>Nombre:</b> <font face="Courier">datalake-ingesta-exec-dev</font> &nbsp;&nbsp; '
    '<b>Plano:</b> Data Plane &nbsp;&nbsp; <b>Uso:</b> lo asume la función Lambda que consume el '
    'stream y escribe en la capa RAW.', S['body']))

story.append(Paragraph('4.1 Trust Policy', S['h2']))
story.append(Paragraph(
    'El rol solo puede ser asumido por el servicio Lambda, y únicamente en nombre de la función '
    'concreta de este proyecto. Las condiciones <font face="Courier">aws:SourceAccount</font> y '
    '<font face="Courier">aws:SourceArn</font> previenen el problema del <i>confused deputy</i>: sin '
    'ellas, cualquier función Lambda de cualquier cuenta podría inducir al servicio a asumir este rol.',
    S['body']))
story.append(code_block([
    '{',
    '  "Version": "2012-10-17",',
    '  "Statement": [{',
    '    "Effect": "Allow",',
    '    "Principal": { "Service": "lambda.amazonaws.com" },',
    '    "Action": "sts:AssumeRole",',
    '    "Condition": {',
    '      "StringEquals": { "aws:SourceAccount": "111122223333" },',
    '      "ArnLike": {',
    '        "aws:SourceArn":',
    '          "arn:aws:lambda:us-east-1:111122223333:function:ingesta-kinesis-s3-dev"',
    '      }',
    '    }',
    '  }]',
    '}',
]))

story.append(Paragraph('4.2 Permisos', S['h2']))
ejec = [
    TH3,
    [P('kinesis:GetRecords<br/>kinesis:GetShardIterator<br/>kinesis:ListShards<br/>kinesis:DescribeStreamSummary', 'mono'), P('${STREAM}', 'mono'),
     P('Consumo del stream. Es el conjunto mínimo que exige el event source mapping de Lambda.')],
    [P('kinesis:PutRecord<br/>kinesis:PutRecords', 'monod'), P('-', 'monod'),
     P('<b>NO SE CONCEDE.</b> Este proceso consume, no produce. Sin permiso de escritura, un defecto o un compromiso no puede contaminar la fuente con registros falsos.')],
    [P('kinesis:DeleteStream<br/>kinesis:MergeShards<br/>kinesis:SplitShards', 'monod'), P('-', 'monod'),
     P('<b>NO SE CONCEDE.</b> Son control plane. El proceso de datos nunca altera la topología del stream: eso corresponde al pipeline.')],
    [P('s3:PutObject', 'mono'), P('${BUCKET}/raw/*', 'mono'),
     P('Escritura acotada al prefijo raw/. No puede escribir en capas posteriores (curated/, analytics/), que tienen otros duenos y otros procesos.')],
    [P('s3:AbortMultipartUpload', 'mono'), P('${BUCKET}/raw/*', 'mono'),
     P('Permiso de soporte que el SDK requiere para cargas multiparte. Sin el, un fallo a mitad de carga deja partes huérfanas que siguen facturando.')],
    [P('s3:ListBucket<br/><i>con Condition</i><br/>s3:prefix = raw/*', 'mono'), P('${BUCKET}', 'mono'),
     P('ListBucket es un permiso de bucket, no de objeto: sin la condición de prefijo el proceso podría enumerar el bucket completo.')],
    [P('s3:DeleteObject', 'monod'), P('-', 'monod'),
     P('<b>NO SE CONCEDE.</b> La capa RAW es append-only y funciona como fuente de verdad. Sin borrado, ningún defecto del proceso puede destruir el histórico.')],
    [P('s3:GetObject', 'monod'), P('-', 'monod'),
     P('<b>NO SE CONCEDE.</b> El proceso escribe pero no relee. Si el diseño lo requiriera, se acotaria al mismo prefijo raw/.')],
    [P('kms:GenerateDataKey', 'mono'), P('${KMS}', 'mono'),
     P('<b>Permiso de soporte obligatorio.</b> Con SSE-KMS activo, PutObject falla sin el: S3 necesita solicitar una data key para cifrar cada objeto. Es la omisión más habitual en este tipo de matriz.')],
    [P('kms:Decrypt', 'mono'), P('${KMS}', 'mono'),
     P('Necesario porque el stream está cifrado con la misma CMK: sin este permiso, GetRecords devuelve los registros ilegibles.')],
    [P('logs:CreateLogStream<br/>logs:PutLogEvents', 'mono'), P('${LOG_GRP}', 'mono'),
     P('Observabilidad del proceso. Se omite CreateLogGroup a propósito: el grupo lo crea Terraform con su retención definida, de modo que el proceso no pueda generar grupos sin política de expiración.')],
    [P('glue:GetTable<br/>glue:GetPartitions<br/>glue:BatchCreatePartition', 'mono'), P('${GLUE_DB}<br/>${GLUE_TBL}', 'mono'),
     P('Registrar las particiones nuevas a medida que llegan datos. Sin UpdateTable ni DeleteTable: no puede alterar el esquema, solo agregar particiones.')],
]
story.append(tabla(ejec, W3, deny_rows=(2, 3, 7, 8)))

# ---------------------------------------------------------- 5. operador ---
story.append(Paragraph('5. Rol de Operador Humano (Data Engineer)', S['h1']))
story.append(Paragraph(
    '<b>Nombre:</b> <font face="Courier">datalake-operador-dev</font> &nbsp;&nbsp; '
    '<b>Plano:</b> solo lectura &nbsp;&nbsp; <b>Uso:</b> monitoreo y depuración en desarrollo. '
    '<b>No existe un rol equivalente en producción:</b> allí el diagnostico se hace sobre métricas y '
    'logs agregados, sin acceso a los datos.', S['body']))

story.append(Paragraph('5.1 Trust Policy', S['h2']))
story.append(Paragraph(
    'Se asume desde la cuenta de identidades, con MFA obligatorio y vigencia acotada. La condición '
    'sobre <font face="Courier">MultiFactorAuthAge</font> exige que el segundo factor se haya '
    'presentado dentro de la última hora, de modo que una sesión olvidada no siga habilitando el '
    'acceso indefinidamente.', S['body']))
story.append(code_block([
    '{',
    '  "Version": "2012-10-17",',
    '  "Statement": [{',
    '    "Effect": "Allow",',
    '    "Principal": { "AWS": "arn:aws:iam::999988887777:root" },',
    '    "Action": "sts:AssumeRole",',
    '    "Condition": {',
    '      "Bool": { "aws:MultiFactorAuthPresent": "true" },',
    '      "NumericLessThan": { "aws:MultiFactorAuthAge": "3600" }',
    '    }',
    '  }]',
    '}',
    '',
    'MaxSessionDuration: 3600 segundos',
]))

story.append(Paragraph('5.2 Permisos', S['h2']))
oper = [
    TH3,
    [P('logs:FilterLogEvents<br/>logs:GetLogEvents<br/>logs:StartQuery<br/>logs:GetQueryResults', 'mono'), P('${LOG_GRP}', 'mono'),
     P('Depuración sobre los logs del proceso de ingesta, acotada al grupo del entorno de desarrollo.')],
    [P('cloudwatch:GetMetricData<br/>cloudwatch:ListMetrics<br/>cloudwatch:DescribeAlarms', 'mono'), P('* (ver nota)', 'mono'),
     P('CloudWatch no admite permisos a nivel de recurso para estas acciones: la API no expone ARNs de métrica. Se acepta el comodín porque son operaciones de <b>solo lectura</b> sobre datos agregados. El criterio de no usar comodines aplica a acciones de escritura.')],
    [P('kinesis:DescribeStreamSummary<br/>kinesis:ListShards', 'mono'), P('${STREAM}', 'mono'),
     P('Diagnostico de la ingesta: antigüedad del iterador, throttling, número de shards.')],
    [P('kinesis:GetRecords<br/>kinesis:GetShardIterator', 'mono'), P('${STREAM}', 'mono'),
     P('Inspección de registros para depurar formato. Concede acceso a datos reales, y por eso este rol existe únicamente en desarrollo y su uso queda auditado como data event.')],
    [P('s3:ListBucket<br/>s3:GetObject', 'mono'), P('${BUCKET}<br/>${BUCKET}/raw/*', 'mono'),
     P('Verificar los archivos generados por la ingesta. Lectura exclusivamente: ninguna acción de escritura.')],
    [P('kms:Decrypt', 'mono'), P('${KMS}', 'mono'),
     P('Permiso de soporte: sin el, GetObject sobre objetos cifrados con SSE-KMS falla con AccessDenied aunque el permiso de S3 esté concedido.')],
    [P('glue:GetDatabase / GetTable<br/>glue:GetPartitions<br/>glue:GetJobRun / GetJobRuns', 'mono'), P('${GLUE_DB}<br/>${GLUE_TBL}', 'mono'),
     P('Consultar esquema y estado de ejecuciones. Sin StartJobRun: relanzar un job es una operación de cambio y va por el pipeline.')],
    [P('<b>Deny</b> sobre<br/>s3:PutObject / DeleteObject<br/>kinesis:PutRecord<br/>glue:StartJobRun / UpdateTable', 'monod'), P('*', 'monod'),
     P('Deny explícito sobre toda acción de modificación. El operador observa; los cambios se aplican por el pipeline, donde quedan versionados y revisados. Un Deny con comodín <b>restringe</b>, no concede: no contradice el criterio de no usar Resource "*".')],
    [P('<b>Deny</b> sobre<br/>toda acción', 'monod'), P('arn:aws:*:*:444455556666:*', 'monod'),
     P('Barrera de entorno. Aunque una política futura concediera permisos amplios, el Deny explícito prevalece y mantiene al operador fuera de producción.')],
]
story.append(tabla(oper, W3, deny_rows=(8, 9)))

story.append(Spacer(1, 0.25 * cm))
story.append(callout(
    'POR QUÉ EL OPERADOR NO PUEDE ESCRIBIR',
    'Un permiso de escritura concedido a una persona rompe la trazabilidad de la infraestructura: el '
    'estado real deja de coincidir con el código y Terraform revierte o duplica recursos en el '
    'siguiente apply. Restringir al operador a lectura no es desconfianza, es preservar el modelo '
    'declarativo.'))

# --------------------------------------------------------- 6. auditoría ---
story.append(Paragraph('6. Estrategia de Auditoría', S['h1']))
story.append(Paragraph(
    'Los permisos definen lo que <i>puede</i> ocurrir; la auditoría registra lo que <i>ocurrió</i>. '
    'Sin trazabilidad, una política mal acotada puede explotarse durante meses sin dejar rastro. '
    'Los registros se centralizan en una cuenta de auditoría independiente, a la que ninguno de los '
    'tres roles descritos tiene acceso: quien puede actuar no puede borrar la evidencia de su acción.',
    S['body']))

audit = [
    [P('Servicio', 'th'), P('Qué registra', 'th'), P('Roles vigilados', 'th'), P('Configuración clave', 'th')],
    [P('CloudTrail<br/><i>management events</i>', 'cellb'), P('Toda llamada de control plane: CreateStream, CreateBucket, PutRolePolicy, CreateKey'), P('Despliegue<br/>Operador'), P('Trail de organización, multi-región, validación de integridad de archivos y destino en cuenta de auditoría con Object Lock')],
    [P('CloudTrail<br/><i>data events</i>', 'cellb'), P('Acceso a datos: s3:GetObject / PutObject y kinesis:GetRecords / PutRecord'), P('Ejecución<br/>Operador'), P('<b>No se registran por defecto.</b> Hay que habilitarlos por bucket y por stream. Tienen costo por evento, así que se acotan a ${BUCKET} y ${STREAM}')],
    [P('CloudWatch Logs<br/>+ Metric Filters', 'cellb'), P('Logs de ejecución del proceso y errores de aplicación'), P('Ejecución'), P('Retención 30 días en dev y 400 en producción. Filtro sobre AccessDenied que dispara alarma')],
    [P('AWS Config', 'cellb'), P('Deriva de configuración respecto del estado declarado'), P('Todos'), P('Reglas s3-bucket-server-side-encryption-enabled, s3-bucket-public-read-prohibited e iam-policy-no-statements-with-admin-access')],
    [P('IAM Access Analyzer', 'cellb'), P('Políticas que conceden acceso externo y permisos concedidos pero nunca usados'), P('Todos'), P('Analizador a nivel organización. Los hallazgos de acceso no usado se revisan cada mes para podar permisos sobrantes')],
    [P('GuardDuty', 'cellb'), P('Uso anómalo de credenciales y patrones de exfiltración'), P('Todos'), P('Habilitado en todas las cuentas; hallazgos de severidad alta enrutados a SNS')],
]
story.append(tabla(audit, [3.0 * cm, 4.4 * cm, 2.4 * cm, 8.0 * cm]))

story.append(Paragraph('6.1 Matriz de trazabilidad por rol', S['h2']))
traza = [
    [P('Rol', 'th'), P('Evento característico', 'th'), P('Dónde queda registrado', 'th'), P('Alerta configurada', 'th')],
    [P('Despliegue', 'cellb'), P('iam:PutRolePolicy, kms:PutKeyPolicy', 'mono'), P('CloudTrail management events'), P('Cambio de política IAM fuera de la ventana de despliegue')],
    [P('Despliegue', 'cellb'), P('sts:AssumeRoleWithWebIdentity', 'mono'), P('CloudTrail + logs de GitHub Actions'), P('Asunción desde un repositorio o rama no autorizados')],
    [P('Ejecución', 'cellb'), P('s3:PutObject, kms:GenerateDataKey', 'mono'), P('CloudTrail data events'), P('Escritura fuera del prefijo raw/')],
    [P('Ejecución', 'cellb'), P('AccessDenied en cualquier acción', 'mono'), P('CloudWatch Logs + metric filter'), P('Cualquier ocurrencia: indica permiso faltante o intento fuera de alcance')],
    [P('Operador', 'cellb'), P('s3:GetObject, kinesis:GetRecords', 'mono'), P('CloudTrail data events'), P('Volumen de lectura inusual, o lectura por un principal distinto del rol de ejecución')],
    [P('Operador', 'cellb'), P('sts:AssumeRole sin MFA', 'mono'), P('CloudTrail management events'), P('Intento de asunción sin segundo factor')],
]
story.append(tabla(traza, [2.4 * cm, 4.6 * cm, 4.4 * cm, 6.4 * cm]))

story.append(Spacer(1, 0.3 * cm))
story.append(callout(
    'LA OMISIÓN MÁS COSTOSA',
    'Los data events de CloudTrail están desactivados por defecto. Una matriz de permisos impecable '
    'sin ellos deja sin registro precisamente lo que más importa: quién leyó qué dato y cuándo. Los '
    'management events dirían que el bucket existe, pero no que alguien descargó su contenido.'))

story.append(Paragraph('7. Conclusión', S['h1']))
story.append(Paragraph(
    'El modelo descansa en tres barreras independientes. La primera es la <b>separación de planos</b>: '
    'quien crea la infraestructura no accede a los datos, y quien procesa datos no modifica la '
    'infraestructura. La segunda es el <b>acotamiento por ARN</b>: cada permiso apunta a recursos '
    'nombrados, de modo que el alcance de una credencial comprometida queda limitado a un entorno. La '
    'tercera es la <b>independencia de la CMK</b>: el cifrado actua como control adicional, y por eso '
    'el rol de despliegue puede crear la clave pero no usarla.', S['body']))
story.append(Paragraph(
    'El efecto conjunto es que ningún compromiso individual basta para acceder al Data Lake. Un '
    'atacante que obtuviera las credenciales del pipeline podría dañar la infraestructura, pero no '
    'leer un solo registro; uno que comprometiera el proceso de ingesta podría escribir en el prefijo '
    'raw/, pero no borrar el histórico ni alcanzar producción. Esa es la reducción del blast radius '
    'que persigue el diseño.', S['body']))

# ============================================================================
# BUILD
# ============================================================================
if __name__ == '__main__':
    salida = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          'Matriz_IAM_DaianaAranda.pdf')
    doc = SimpleDocTemplate(
        salida, pagesize=A4,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=MARGIN + 0.35 * cm, bottomMargin=MARGIN + 0.35 * cm,
        title=TITULO, author=AUTOR,
        subject='Matriz de control de acceso IAM para plataforma de streaming en AWS',
    )
    doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)
    print('PDF generado: %s' % salida)
    print('Paginas: %d' % doc.page)
